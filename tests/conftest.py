"""Shared fixtures for the Rick Arko portfolio test suite."""

from __future__ import annotations

import pytest

from rickarko_portfolio import create_app
from rickarko_portfolio.config import (
    DEFAULT_DATA_DIR,
    DEFAULT_FLASK_ENV,
    DEFAULT_PORT,
    DEFAULT_SITE_URL,
    DEFAULT_STATIC_DIR,
    DEFAULT_TEMPLATE_DIR,
    build_settings,
    clear_settings_cache,
)
from rickarko_portfolio.content import clear_content_cache


@pytest.fixture(autouse=True)
def reset_runtime_state(monkeypatch: pytest.MonkeyPatch):
    """Keep tests deterministic regardless of the developer's local shell."""

    monkeypatch.setenv("SITE_URL", DEFAULT_SITE_URL)
    monkeypatch.setenv("FLASK_ENV", DEFAULT_FLASK_ENV)
    monkeypatch.setenv("PORT", str(DEFAULT_PORT))
    monkeypatch.delenv("APP_DATA_DIR", raising=False)
    monkeypatch.delenv("APP_TEMPLATE_DIR", raising=False)
    monkeypatch.delenv("APP_STATIC_DIR", raising=False)
    clear_settings_cache()
    clear_content_cache()
    yield
    clear_settings_cache()
    clear_content_cache()


@pytest.fixture()
def settings():
    """Return explicit settings so most tests do not depend on the environment."""

    return build_settings(
        site_url=DEFAULT_SITE_URL,
        flask_env=DEFAULT_FLASK_ENV,
        port=DEFAULT_PORT,
        data_dir=DEFAULT_DATA_DIR,
        template_dir=DEFAULT_TEMPLATE_DIR,
        static_dir=DEFAULT_STATIC_DIR,
    )


@pytest.fixture()
def app(settings):
    """Create a Flask app configured for tests."""

    return create_app(settings=settings, config_overrides={"TESTING": True})


@pytest.fixture()
def app_factory():
    """Factory fixture for tests that need environment-driven settings."""

    def _create_app(*, settings=None, config_overrides=None):
        overrides = {"TESTING": True}
        if config_overrides:
            overrides.update(config_overrides)
        return create_app(settings=settings, config_overrides=overrides)

    return _create_app


@pytest.fixture()
def client(app):
    """Yield a Flask test client."""

    with app.test_client() as test_client:
        yield test_client


@pytest.fixture()
def runner(app):
    """Yield a Flask CLI runner."""

    return app.test_cli_runner()


@pytest.fixture()
def request_context(app):
    """Yield a request context for URL-generation tests."""

    with app.test_request_context("/"):
        yield
