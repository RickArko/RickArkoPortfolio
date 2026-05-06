"""Integration tests for Flask application creation and wiring."""

from __future__ import annotations

from pathlib import Path

import pytest
from flask import url_for

from rickarko_portfolio.config import clear_settings_cache

pytestmark = pytest.mark.integration


def test_create_app_uses_expected_template_and_static_paths(app, settings):
    """The app factory should point Flask at the repo's template and static dirs."""

    assert Path(app.template_folder) == settings.template_dir
    assert Path(app.static_folder) == settings.static_dir
    assert app.config["SETTINGS"] == settings


def test_create_app_registers_expected_routes(app):
    """The application should expose the public routes relied upon in production."""

    registered_rules = {rule.rule for rule in app.url_map.iter_rules()}

    assert {
        "/",
        "/home/",
        "/experience/",
        "/projects/",
        "/blog/",
        "/contact/",
        "/sign-in/",
        "/sign-out/",
        "/robots.txt",
        "/sitemap.xml",
        "/health",
    } <= registered_rules


def test_request_context_resolves_named_routes(request_context):
    """Named route lookups should work inside an application request context."""

    assert url_for("experience") == "/experience/"
    assert url_for("projects") == "/projects/"
    assert url_for("contact") == "/contact/"
    assert url_for("sign_in") == "/sign-in/"


def test_environment_override_updates_rendered_canonical_url(
    app_factory,
    monkeypatch: pytest.MonkeyPatch,
):
    """Environment-provided settings should affect rendered SEO output."""

    monkeypatch.setenv("SITE_URL", "https://preview.example.test")
    clear_settings_cache()
    app = app_factory(settings=None)

    with app.test_client() as client:
        body = client.get("/").data.decode()

    assert 'rel="canonical" href="https://preview.example.test/"' in body


def test_app_factory_boots_with_production_like_settings(
    app_factory,
    monkeypatch: pytest.MonkeyPatch,
):
    """A production-flavored configuration should still render pages correctly."""

    monkeypatch.setenv("FLASK_ENV", "production")
    clear_settings_cache()
    app = app_factory(settings=None, config_overrides={"TESTING": False})

    assert app.config["SETTINGS"].flask_env == "production"

    with app.test_client() as client:
        response = client.get("/")

    assert response.status_code == 200
