"""Content loading helpers for JSON-backed portfolio pages."""

from __future__ import annotations

import json
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from .config import Settings, get_settings

JSONMapping = dict[str, Any]


@dataclass(frozen=True)
class SiteProfile:
    """Typed projection of the site profile content."""

    name: str
    headline: str
    short_tagline: str
    email: str
    linkedin_url: str
    github_url: str
    medium_url: str
    availability: str
    location: str


@lru_cache(maxsize=None)
def load_json_file(path: Path) -> JSONMapping:
    """Load JSON content from disk with caching."""

    with Path(path).open(encoding="utf-8") as handle:
        return json.load(handle)


def clear_content_cache() -> None:
    """Clear cached content so tests can validate environment overrides."""

    load_json_file.cache_clear()


def load_home_content(settings: Settings | None = None) -> JSONMapping:
    resolved_settings = settings or get_settings()
    return load_json_file(resolved_settings.home_path)


def load_experience_content(settings: Settings | None = None) -> JSONMapping:
    resolved_settings = settings or get_settings()
    return load_json_file(resolved_settings.experience_path)


def load_projects_content(settings: Settings | None = None) -> JSONMapping:
    resolved_settings = settings or get_settings()
    return load_json_file(resolved_settings.projects_path)


def load_site_profile(settings: Settings | None = None) -> SiteProfile:
    resolved_settings = settings or get_settings()
    return SiteProfile(**load_home_content(resolved_settings)["profile"])
