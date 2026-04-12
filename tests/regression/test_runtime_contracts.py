"""Regression tests for runtime and deployment-sensitive contracts."""

from __future__ import annotations

import importlib

import pytest
from flask import Flask

from rickarko_portfolio import __main__ as main_module
from rickarko_portfolio.config import clear_settings_cache

pytestmark = pytest.mark.regression


def test_wsgi_entrypoint_exports_flask_application_objects():
    """The package WSGI module should expose importable Flask application objects."""

    module = importlib.import_module("rickarko_portfolio.wsgi")

    assert isinstance(module.app, Flask)
    assert module.application is module.app


def test_module_entrypoint_runs_flask_app(monkeypatch: pytest.MonkeyPatch):
    """The package CLI entrypoint should delegate to Flask.run with parsed arguments."""

    captured: dict[str, object] = {}

    def fake_run(self, *, host, port, debug):  # noqa: ANN001
        captured["app"] = self
        captured["host"] = host
        captured["port"] = port
        captured["debug"] = debug

    monkeypatch.setattr(Flask, "run", fake_run)

    main_module.main(["--host", "127.0.0.1", "--port", "9090", "--debug"])

    assert captured["host"] == "127.0.0.1"
    assert captured["port"] == 9090
    assert captured["debug"] is True
    assert isinstance(captured["app"], Flask)


def test_site_url_override_updates_robots_and_sitemap(
    app_factory,
    monkeypatch: pytest.MonkeyPatch,
):
    """Environment overrides should propagate to deployment-critical text endpoints."""

    monkeypatch.setenv("SITE_URL", "https://preview.example.test")
    clear_settings_cache()
    app = app_factory(settings=None)

    with app.test_client() as client:
        robots = client.get("/robots.txt").data.decode()
        sitemap = client.get("/sitemap.xml").data.decode()

    assert "Sitemap: https://preview.example.test/sitemap.xml" in robots
    assert "https://preview.example.test/" in sitemap
