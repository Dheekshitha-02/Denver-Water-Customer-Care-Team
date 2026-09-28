"""HTML parsing and main-content extraction for denverwater.org pages."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Iterable, Optional
from urllib.parse import urlparse

from bs4 import BeautifulSoup, Tag

# Elements removed wholesale before text extraction.
_REMOVE_TAGS = (
    "script",
    "style",
    "noscript",
    "svg",
    "iframe",
    "form",
    "nav",
    "footer",
    "header",
    "aside",
)

# Class/id substrings that usually indicate chrome / cookie UI.
_BOILERPLATE_HINTS = (
    "cookie",
    "consent",
    "banner",
    "newsletter",
    "breadcrumb",
    "social-share",
    "share-links",
    "skip-link",
    "site-header",
    "site-footer",
    "main-menu",
    "secondary-menu",
    "utility-nav",
    "region-header",
    "region-footer",
    "region-sidebar",
    "block-menu",
    "pager",
    "pagination",
)

_MAIN_SELECTORS = (
    "main",
    "[role='main']",
    "#main-content",
    "#main",
    ".region-content",
    ".main-content",
    "article",
    ".node__content",
    ".field--name-body",
)

_HEADING_TAGS = frozenset({"h1", "h2", "h3", "h4", "h5", "h6"})


@dataclass
class ParsedPage:
    """Structured fields extracted from a single HTML document."""

    title: str
    content: str
    category: str
    meta_description: Optional[str]
    last_modified: Optional[str]
    links: list[str]


def page_id_for_url(url: str) -> str:
    """Stable primary key derived from the canonical URL."""
    return hashlib.sha256(url.encode("utf-8")).hexdigest()


def content_hash_for_text(content: str) -> str:
    """SHA-256 of normalized main text for change detection."""
    normalized = re.sub(r"\s+", " ", (content or "").strip()).lower()
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def category_from_url(url: str) -> str:
    """Derive a path-based category, e.g. residential/billing-and-rates."""
    path = (urlparse(url).path or "/").strip("/")
    return path or "home"


def _attr_blob(tag: Tag) -> str:
    parts: list[str] = []
    for key in ("id", "class", "role"):
        value = tag.get(key)
        if isinstance(value, list):
            parts.extend(str(v) for v in value)
        elif value:
            parts.append(str(value))
    return " ".join(parts).lower()


def _is_boilerplate(tag: Tag) -> bool:
    blob = _attr_blob(tag)
    return any(hint in blob for hint in _BOILERPLATE_HINTS)


def _find_main_root(soup: BeautifulSoup) -> Tag:
    for selector in _MAIN_SELECTORS:
        found = soup.select_one(selector)
        if found is not None:
            return found
    return soup.body if soup.body is not None else soup


def _strip_boilerplate(root: Tag) -> None:
    for tag_name in _REMOVE_TAGS:
        for node in root.find_all(tag_name):
            node.decompose()

    # Second pass for chrome containers that are not semantic nav/footer tags.
    for node in list(root.find_all(True)):
        if not isinstance(node, Tag):
            continue
        if node.name in ("html", "body", "main", "article"):
            continue
        if _is_boilerplate(node):
            node.decompose()


def _extract_text(root: Tag) -> str:
    """Pull headings and block text in document order; skip nested duplicates."""
    lines: list[str] = []
    seen_blocks: set[int] = set()

    for node in root.find_all(
        list(_HEADING_TAGS | {"p", "li", "td", "th", "blockquote", "figcaption"})
    ):
        # Prefer the outermost meaningful block when nested tags match.
        parent = node.parent
        skip = False
        while isinstance(parent, Tag):
            if id(parent) in seen_blocks:
                skip = True
                break
            parent = parent.parent
        if skip:
            continue

        text = node.get_text(" ", strip=True)
        text = re.sub(r"\s+", " ", text).strip()
        if not text:
            continue
        lines.append(text)
        seen_blocks.add(id(node))

    if not lines:
        fallback = root.get_text("\n", strip=True)
        fallback = re.sub(r"[ \t]+", " ", fallback)
        fallback = re.sub(r"\n{3,}", "\n\n", fallback)
        return fallback.strip()

    return "\n".join(lines).strip()

def _meta_content(soup: BeautifulSoup, *names: str) -> Optional[str]:
    for name in names:
        tag = soup.find("meta", attrs={"name": name}) or soup.find(
            "meta", attrs={"property": name}
        )
        if tag and tag.get("content"):
            value = str(tag["content"]).strip()
            if value:
                return value
    return None


def _parse_last_modified(
    soup: BeautifulSoup, header_value: Optional[str]
) -> Optional[str]:
    candidates: list[str] = []
    if header_value:
        candidates.append(header_value)

    meta = _meta_content(
        soup,
        "last-modified",
        "article:modified_time",
        "og:updated_time",
        "dateModified",
    )
    if meta:
        candidates.append(meta)

    time_tag = soup.find("time", attrs={"datetime": True})
    if time_tag and time_tag.get("datetime"):
        candidates.append(str(time_tag["datetime"]))

    for raw in candidates:
        try:
            if "," in raw and "GMT" in raw.upper():
                dt = parsedate_to_datetime(raw)
            else:
                text = raw.strip()
                if text.endswith("Z"):
                    text = text[:-1] + "+00:00"
                dt = datetime.fromisoformat(text)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except (TypeError, ValueError, IndexError, OverflowError):
            continue
    return None


def extract_links(html: str, base_url: str) -> list[str]:
    """Return raw href values from anchor tags (caller normalizes/filters)."""
    soup = BeautifulSoup(html, "lxml")
    links: list[str] = []
    for anchor in soup.find_all("a", href=True):
        href = str(anchor["href"]).strip()
        if href:
            links.append(href)
    return links


def parse_page(
    html: str,
    url: str,
    *,
    last_modified_header: Optional[str] = None,
) -> ParsedPage:
    """Parse HTML into cleaned content fields and outbound links."""
    soup = BeautifulSoup(html, "lxml")

    title = ""
    if soup.title and soup.title.string:
        title = soup.title.get_text(" ", strip=True)
    h1 = soup.find("h1")
    if not title and h1:
        title = h1.get_text(" ", strip=True)

    meta_description = _meta_content(soup, "description", "og:description")
    last_modified = _parse_last_modified(soup, last_modified_header)

    # Work on a clone of the main region so link extraction can use full doc.
    root = _find_main_root(soup)
    working = BeautifulSoup(str(root), "lxml")
    work_root = working.body if working.body is not None else working
    _strip_boilerplate(work_root)
    content = _extract_text(work_root)

    links = extract_links(html, url)

    return ParsedPage(
        title=title,
        content=content,
        category=category_from_url(url),
        meta_description=meta_description,
        last_modified=last_modified,
        links=links,
    )


def discover_links(html: str, base_url: str) -> Iterable[str]:
    """Adapter used by the crawler to discover followable hrefs."""
    return extract_links(html, base_url)
