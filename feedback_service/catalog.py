from __future__ import annotations

import json
import math
import threading
import time
import urllib.error
import urllib.request
from collections import OrderedDict
from dataclasses import dataclass


class CatalogUnavailable(Exception):
    pass


@dataclass(frozen=True)
class _CacheEntry:
    expires_at: float
    value: dict


class StudyPlannerCatalog:
    def __init__(
        self,
        base_url: str,
        timeout_seconds: float = 8,
        cache_seconds: float = 300,
        max_cache_entries: int = 64,
    ):
        self.search_url = f"{base_url.rstrip('/')}/api/ai/catalog/search"
        self.timeout_seconds = timeout_seconds
        self.cache_seconds = cache_seconds
        self.max_cache_entries = max_cache_entries
        self._cache: OrderedDict[tuple[str, int], _CacheEntry] = OrderedDict()
        self._lock = threading.Lock()

    @property
    def cache_entries(self) -> int:
        with self._lock:
            return len(self._cache)

    def search(self, query: str, limit: int) -> dict:
        key = (query.casefold(), limit)
        current = time.monotonic()
        with self._lock:
            cached = self._cache.get(key)
            if cached and cached.expires_at > current:
                self._cache.move_to_end(key)
                return cached.value

        request = urllib.request.Request(
            self.search_url,
            data=json.dumps(
                {"query": query, "limit": limit, "periodId": "all"}
            ).encode(),
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json",
                "User-Agent": "StudyOS-Course-Ratings/1.0",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(
                request, timeout=self.timeout_seconds
            ) as response:
                raw = response.read(256_001)
        except (OSError, urllib.error.HTTPError, urllib.error.URLError) as error:
            raise CatalogUnavailable(
                "course catalog is temporarily unavailable"
            ) from error
        if len(raw) > 256_000:
            raise CatalogUnavailable("course catalog response is too large")
        try:
            payload = json.loads(raw)
            courses = payload["courses"]
            if not isinstance(courses, list):
                raise TypeError
        except (json.JSONDecodeError, KeyError, TypeError) as error:
            raise CatalogUnavailable(
                "course catalog returned an invalid response"
            ) from error

        cleaned = [self._course(item) for item in courses[:limit]]
        value = {
            "courses": [course for course in cleaned if course is not None],
            "count": payload.get("count", len(courses)),
            "truncated": bool(payload.get("truncated", False)),
        }
        with self._lock:
            self._cache[key] = _CacheEntry(current + self.cache_seconds, value)
            self._cache.move_to_end(key)
            while len(self._cache) > self.max_cache_entries:
                self._cache.popitem(last=False)
        return value

    @staticmethod
    def _course(item: object) -> dict | None:
        if not isinstance(item, dict):
            return None
        required = ("courseId", "courseNumber", "title")
        if any(not isinstance(item.get(key), str) for key in required):
            return None
        course_id = item["courseId"].strip()[:80]
        number = item["courseNumber"].strip()[:120]
        title = item["title"].strip()[:300]
        if not course_id or not number or not title:
            return None
        period = item.get("periodLabel")
        lecturer = item.get("lecturer")
        ects = item.get("ects")
        types = item.get("types")
        return {
            "courseId": course_id,
            "courseNumber": number,
            "title": title,
            "periodLabel": period.strip()[:80] if isinstance(period, str) else "",
            "ects": ects
            if not isinstance(ects, bool)
            and isinstance(ects, (int, float))
            and math.isfinite(ects)
            else None,
            "lecturer": lecturer.strip()[:200]
            if isinstance(lecturer, str) and lecturer.strip()
            else None,
            "types": [
                value.strip()[:80] for value in types[:10] if isinstance(value, str)
            ]
            if isinstance(types, list)
            else [],
        }
