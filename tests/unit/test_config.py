"""Unit tests for runtime settings helpers."""

from __future__ import annotations

from pathlib import Path

import pytest

from rickarko_portfolio.config import (
    DEFAULT_DATA_DIR,
    DEFAULT_STATIC_DIR,
    DEFAULT_TEMPLATE_DIR,
    build_settings,
    clear_settings_cache,
    get_settings,
)

pytestmark = pytest.mark.unit


def test_build_settings_normalizes_site_url_and_paths():
    """Explicit settings should produce normalized paths and URLs."""

    settings = build_settings(
        site_url="https://example.test/",
        data_dir=DEFAULT_DATA_DIR,
        template_dir=DEFAULT_TEMPLATE_DIR,
        static_dir=DEFAULT_STATIC_DIR,
    )

    assert settings.site_url == "https://example.test"
    assert settings.home_path == Path(DEFAULT_DATA_DIR).resolve() / "home.json"
    assert settings.template_dir == Path(DEFAULT_TEMPLATE_DIR).resolve()
    assert settings.static_dir == Path(DEFAULT_STATIC_DIR).resolve()
    assert (
        settings.site_image_url
        == "https://example.test/static/images/profile-image.png"
    )


def test_get_settings_reads_environment_overrides(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
):
    """Environment variables should influence settings construction."""

    custom_data = tmp_path / "db"
    custom_templates = tmp_path / "templates"
    custom_static = tmp_path / "static"
    custom_data.mkdir()
    custom_templates.mkdir()
    custom_static.mkdir()

    monkeypatch.setenv("SITE_URL", "https://preview.example.test/")
    monkeypatch.setenv("FLASK_ENV", "development")
    monkeypatch.setenv("PORT", "9090")
    monkeypatch.setenv("APP_DATA_DIR", str(custom_data))
    monkeypatch.setenv("APP_TEMPLATE_DIR", str(custom_templates))
    monkeypatch.setenv("APP_STATIC_DIR", str(custom_static))
    clear_settings_cache()

    settings = get_settings()

    assert settings.site_url == "https://preview.example.test"
    assert settings.flask_env == "development"
    assert settings.port == 9090
    assert settings.data_dir == custom_data.resolve()
    assert settings.template_dir == custom_templates.resolve()
    assert settings.static_dir == custom_static.resolve()
    assert settings.debug_enabled is True
