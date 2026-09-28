"""Postgres client for reading Genesys mock tables from Supabase."""

from __future__ import annotations

from typing import Any, Iterator, Union

import psycopg2
import psycopg2.extras
from fivetran_connector_sdk import Logging as log

from entity_registry import MAX_RECORDS_PER_PAGE


class SupabaseClient:
    """Read-only Postgres client with keyset pagination."""

    def __init__(
        self,
        host: str,
        database: str,
        user: str,
        password: str,
        *,
        port: Union[str, int] = 5432,
        schema: str = "genesys_mock",
        sslmode: str = "require",
    ) -> None:
        self.schema = schema
        self._conn = psycopg2.connect(
            host=host,
            port=int(port),
            dbname=database,
            user=user,
            password=password,
            sslmode=sslmode,
        )
        self._conn.autocommit = True

    def close(self) -> None:
        self._conn.close()

    def _qualified(self, table: str) -> str:
        return f'"{self.schema}"."{table}"'

    def query_table(
        self,
        table: str,
        cursor_field: str,
        cursor_value: Any,
        *,
        cursor_mode: str,
        primary_key: str,
    ) -> Iterator[dict[str, Any]]:
        """Yield rows for the given cursor mode, ordered for keyset pagination."""
        if cursor_mode == "full":
            yield from self._query_full(table, primary_key)
        elif cursor_mode == "primary_key":
            yield from self._query_by_primary_key(table, primary_key, str(cursor_value))
        elif cursor_mode == "datetime":
            yield from self._query_by_datetime(
                table, cursor_field, cursor_value, primary_key
            )
        else:
            raise ValueError(f"Unsupported cursor_mode: {cursor_mode}")

    def _query_full(self, table: str, primary_key: str) -> Iterator[dict[str, Any]]:
        """Read the entire table ordered by primary key (POC-friendly full upsert)."""
        qualified = self._qualified(table)
        last_pk = ""
        total = 0

        while True:
            sql = f"""
                select *
                from {qualified}
                where "{primary_key}" > %s
                order by "{primary_key}" asc
                limit %s
            """
            with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, (last_pk, MAX_RECORDS_PER_PAGE))
                rows = cur.fetchall()

            if not rows:
                break

            for row in rows:
                record = dict(row)
                total += 1
                yield record
                last_pk = str(record[primary_key])

            if len(rows) < MAX_RECORDS_PER_PAGE:
                break

        log.info(f"Fetched {total} row(s) from {self.schema}.{table} (full)")

    def _query_by_primary_key(
        self,
        table: str,
        primary_key: str,
        cursor_value: str,
    ) -> Iterator[dict[str, Any]]:
        qualified = self._qualified(table)
        last_pk = cursor_value
        total = 0

        while True:
            sql = f"""
                select *
                from {qualified}
                where "{primary_key}" > %s
                order by "{primary_key}" asc
                limit %s
            """
            with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, (last_pk, MAX_RECORDS_PER_PAGE))
                rows = cur.fetchall()

            if not rows:
                break

            for row in rows:
                record = dict(row)
                total += 1
                yield record
                last_pk = str(record[primary_key])

            if len(rows) < MAX_RECORDS_PER_PAGE:
                break

        log.info(f"Fetched {total} row(s) from {self.schema}.{table}")

    def _query_by_datetime(
        self,
        table: str,
        cursor_field: str,
        cursor_value: Any,
        primary_key: str,
    ) -> Iterator[dict[str, Any]]:
        """Incremental read on a timestamp/date column with text PK tie-break."""
        qualified = self._qualified(table)
        last_cursor = cursor_value
        last_pk = ""
        total = 0

        while True:
            sql = f"""
                select *
                from {qualified}
                where ("{cursor_field}" > %s)
                   or ("{cursor_field}" = %s and "{primary_key}" > %s)
                order by "{cursor_field}" asc, "{primary_key}" asc
                limit %s
            """
            params: tuple[Any, ...] = (
                last_cursor,
                last_cursor,
                last_pk,
                MAX_RECORDS_PER_PAGE,
            )
            with self._conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(sql, params)
                rows = cur.fetchall()

            if not rows:
                break

            for row in rows:
                record = dict(row)
                total += 1
                yield record
                last_cursor = record[cursor_field]
                last_pk = str(record[primary_key])

            if len(rows) < MAX_RECORDS_PER_PAGE:
                break

        log.info(f"Fetched {total} row(s) from {self.schema}.{table}")
