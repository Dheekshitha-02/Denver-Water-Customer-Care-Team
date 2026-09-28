"""Scoped HTTP crawler for denverwater.org public pages."""

from __future__ import annotations

import time
import urllib.robotparser
from collections import deque
from dataclasses import dataclass
from typing import Iterable, Optional
from urllib.parse import parse_qsl, urlencode, urljoin, urlparse, urlunparse

import requests

try:
    from fivetran_connector_sdk import Logging as log
except Exception:  # noqa: BLE001
    log = None


def _info(message: str) -> None:
    if log is not None:
        try:
            log.info(message)
            return
        except Exception:  # noqa: BLE001
            pass
    print(message)


def _warning(message: str) -> None:
    if log is not None:
        try:
            log.warning(message)
            return
        except Exception:  # noqa: BLE001
            pass
    print(message)

# Tracking / session params to drop during URL normalization.
_STRIP_QUERY_KEYS = frozenset(
    {
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_term",
        "utm_content",
        "fbclid",
        "gclid",
        "mc_cid",
        "mc_eid",
    }
)

_NON_HTML_EXTENSIONS = frozenset(
    {
        ".pdf",
        ".jpg",
        ".jpeg",
        ".png",
        ".gif",
        ".svg",
        ".webp",
        ".ico",
        ".css",
        ".js",
        ".json",
        ".xml",
        ".zip",
        ".doc",
        ".docx",
        ".xls",
        ".xlsx",
        ".ppt",
        ".pptx",
        ".mp3",
        ".mp4",
        ".avi",
        ".mov",
        ".wmv",
        ".woff",
        ".woff2",
        ".ttf",
        ".eot",
    }
)

_ALLOWED_HOSTS = frozenset({"denverwater.org", "www.denverwater.org"})


@dataclass(frozen=True)
class CrawlTarget:
    """A URL queued for fetch at a given link depth from the seeds."""

    url: str
    depth: int


@dataclass
class FetchResult:
    """Successful or failed HTTP fetch outcome."""

    requested_url: str
    final_url: str
    status_code: Optional[int]
    content_type: str
    html: Optional[str]
    last_modified_header: Optional[str]
    error: Optional[str] = None

    @property
    def ok(self) -> bool:
        return self.error is None and self.html is not None


class DenverWaterCrawler:
    """BFS crawler constrained to denverwater.org and configured path prefixes."""

    def __init__(
        self,
        *,
        base_url: str,
        seed_urls: list[str],
        allowed_path_prefixes: list[str],
        max_pages: int,
        max_depth: int,
        request_delay_seconds: float,
        request_timeout_seconds: float,
        user_agent: str,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.seed_urls = seed_urls
        self.allowed_path_prefixes = allowed_path_prefixes
        self.max_pages = max_pages
        self.max_depth = max_depth
        self.request_delay_seconds = request_delay_seconds
        self.request_timeout_seconds = request_timeout_seconds
        self.user_agent = user_agent

        self._session = requests.Session()
        self._session.headers.update(
            {
                "User-Agent": user_agent,
                "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
            }
        )
        self._robots = self._load_robots()
        self._last_request_at = 0.0

    def _load_robots(self) -> urllib.robotparser.RobotFileParser:
        robots_url = urljoin(self.base_url + "/", "robots.txt")
        parser = urllib.robotparser.RobotFileParser()
        parser.set_url(robots_url)
        try:
            parser.read()
            _info(f"Loaded robots.txt from {robots_url}")
        except Exception as exc:  # noqa: BLE001 — continue crawl if robots unavailable
            _warning(f"Could not load robots.txt ({exc}); allowing public paths by default")
        return parser

    def _throttle(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        remaining = self.request_delay_seconds - elapsed
        if remaining > 0:
            time.sleep(remaining)

    def normalize_url(self, url: str, base: Optional[str] = None) -> Optional[str]:
        """Return a canonical absolute URL or None if out of scope / non-HTML."""
        raw = (url or "").strip()
        if not raw or raw.startswith(("mailto:", "tel:", "javascript:", "data:")):
            return None

        absolute = urljoin(base or self.base_url, raw)
        parsed = urlparse(absolute)
        if parsed.scheme not in ("http", "https"):
            return None

        host = (parsed.hostname or "").lower()
        if host not in _ALLOWED_HOSTS:
            return None

        path = parsed.path or "/"
        lower_path = path.lower()
        for ext in _NON_HTML_EXTENSIONS:
            if lower_path.endswith(ext):
                return None

        # Drop fragment; strip common tracking query params.
        query_pairs = [
            (k, v)
            for k, v in parse_qsl(parsed.query, keep_blank_values=True)
            if k.lower() not in _STRIP_QUERY_KEYS
        ]
        query = urlencode(query_pairs)

        # Prefer https and www host for stable page_id.
        normalized = urlunparse(
            (
                "https",
                "www.denverwater.org",
                path.rstrip("/") if path != "/" else "/",
                "",
                query,
                "",
            )
        )
        return normalized

    def is_allowed_path(self, url: str) -> bool:
        path = urlparse(url).path or "/"
        if path == "/":
            # Homepage is intentionally not in POC seeds/scope.
            return False
        for prefix in self.allowed_path_prefixes:
            if path == prefix.rstrip("/") or path.startswith(prefix):
                return True
        return False

    def is_allowed_by_robots(self, url: str) -> bool:
        try:
            return self._robots.can_fetch(self.user_agent, url)
        except Exception:  # noqa: BLE001
            return True

    def resolve_seed_urls(self) -> list[str]:
        """Normalize configured seeds and keep only in-scope URLs."""
        resolved: list[str] = []
        seen: set[str] = set()
        for seed in self.seed_urls:
            normalized = self.normalize_url(seed)
            if not normalized:
                _warning(f"Skipping invalid seed URL: {seed}")
                continue
            if not self.is_allowed_path(normalized):
                _warning(f"Skipping seed outside allowed prefixes: {normalized}")
                continue
            if not self.is_allowed_by_robots(normalized):
                _warning(f"Skipping seed disallowed by robots.txt: {normalized}")
                continue
            if normalized in seen:
                continue
            seen.add(normalized)
            resolved.append(normalized)
        return resolved

    def fetch(self, url: str) -> FetchResult:
        """Fetch a single URL with throttling; never raises for page-level failures."""
        self._throttle()
        self._last_request_at = time.monotonic()
        try:
            response = self._session.get(
                url,
                timeout=self.request_timeout_seconds,
                allow_redirects=True,
            )
        except requests.Timeout:
            return FetchResult(
                requested_url=url,
                final_url=url,
                status_code=None,
                content_type="",
                html=None,
                last_modified_header=None,
                error="timeout",
            )
        except requests.RequestException as exc:
            return FetchResult(
                requested_url=url,
                final_url=url,
                status_code=None,
                content_type="",
                html=None,
                last_modified_header=None,
                error=str(exc),
            )

        final_url = self.normalize_url(response.url) or response.url
        content_type = (response.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        last_modified = response.headers.get("Last-Modified")

        if response.status_code >= 400:
            return FetchResult(
                requested_url=url,
                final_url=final_url,
                status_code=response.status_code,
                content_type=content_type,
                html=None,
                last_modified_header=last_modified,
                error=f"http_{response.status_code}",
            )

        if content_type and "html" not in content_type and "xml" not in content_type:
            return FetchResult(
                requested_url=url,
                final_url=final_url,
                status_code=response.status_code,
                content_type=content_type,
                html=None,
                last_modified_header=last_modified,
                error=f"non_html:{content_type}",
            )

        # Re-check domain/scope after redirects.
        host = (urlparse(final_url).hostname or "").lower()
        if host not in _ALLOWED_HOSTS:
            return FetchResult(
                requested_url=url,
                final_url=final_url,
                status_code=response.status_code,
                content_type=content_type,
                html=None,
                last_modified_header=last_modified,
                error="redirect_off_domain",
            )

        canonical = self.normalize_url(final_url)
        if not canonical or not self.is_allowed_path(canonical):
            return FetchResult(
                requested_url=url,
                final_url=final_url,
                status_code=response.status_code,
                content_type=content_type,
                html=None,
                last_modified_header=last_modified,
                error="redirect_out_of_scope",
            )

        if not self.is_allowed_by_robots(canonical):
            return FetchResult(
                requested_url=url,
                final_url=canonical,
                status_code=response.status_code,
                content_type=content_type,
                html=None,
                last_modified_header=last_modified,
                error="robots_disallowed",
            )

        return FetchResult(
            requested_url=url,
            final_url=canonical,
            status_code=response.status_code,
            content_type=content_type,
            html=response.text,
            last_modified_header=last_modified,
        )

    def iter_crawl(self, discover_links) -> Iterable[tuple[CrawlTarget, FetchResult]]:
        """
        BFS over seeds up to max_pages / max_depth.

        ``discover_links(html, base_url) -> Iterable[str]`` extracts candidate hrefs.
        """
        queue: deque[CrawlTarget] = deque(
            CrawlTarget(url=seed, depth=0) for seed in self.resolve_seed_urls()
        )
        seen: set[str] = set()
        fetched = 0

        while queue and fetched < self.max_pages:
            target = queue.popleft()
            if target.url in seen:
                continue
            seen.add(target.url)

            if not self.is_allowed_by_robots(target.url):
                _warning(f"robots.txt disallows: {target.url}")
                continue

            result = self.fetch(target.url)
            fetched += 1
            yield target, result

            if not result.ok or result.html is None:
                _warning(
                    f"Fetch failed for {target.url}: {result.error or 'unknown'}"
                )
                continue

            # Mark final URL seen in case of redirect alias.
            if result.final_url != target.url:
                seen.add(result.final_url)

            if target.depth >= self.max_depth:
                continue

            for href in discover_links(result.html, result.final_url):
                normalized = self.normalize_url(href, base=result.final_url)
                if not normalized or normalized in seen:
                    continue
                if not self.is_allowed_path(normalized):
                    continue
                if not self.is_allowed_by_robots(normalized):
                    continue
                queue.append(CrawlTarget(url=normalized, depth=target.depth + 1))

    def close(self) -> None:
        self._session.close()
