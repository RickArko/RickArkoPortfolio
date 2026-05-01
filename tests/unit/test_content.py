"""Unit tests for JSON-backed content helpers."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from rickarko_portfolio.content import (
    clear_content_cache,
    load_home_content,
    load_json_file,
    load_projects_content,
    load_site_profile,
)

pytestmark = pytest.mark.unit


def test_load_json_file_uses_cache_until_cleared(tmp_path: Path):
    """The raw JSON loader should cache file contents until explicitly reset."""

    payload = tmp_path / "payload.json"
    payload.write_text(json.dumps({"value": "first"}), encoding="utf-8")

    assert load_json_file(payload)["value"] == "first"

    payload.write_text(json.dumps({"value": "second"}), encoding="utf-8")
    assert load_json_file(payload)["value"] == "first"

    clear_content_cache()
    assert load_json_file(payload)["value"] == "second"


def test_load_site_profile_returns_typed_profile(settings):
    """The site profile should be projected into a stable typed object."""

    profile = load_site_profile(settings)

    assert profile.name == "Rick Arko"
    assert profile.email == "rickarko@pm.me"
    assert profile.github_url.endswith("/RickArko")


def test_content_loaders_expose_expected_sections(settings):
    """Home and project content should expose the sections the templates depend on."""

    home_content = load_home_content(settings)
    projects_content = load_projects_content(settings)

    assert {"profile", "hero", "about", "services", "wins"} <= set(home_content.keys())
    assert "projects" in projects_content
    assert "Network Forecasting Platform" in {
        project["title"] for project in projects_content["projects"].values()
    }
