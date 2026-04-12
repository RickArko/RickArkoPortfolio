"""Shared fixtures for the RickArkoPortfolio test suite."""

import sys
from pathlib import Path

import pytest

# The app module lives in src/, so add it to the import path.
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from app import app as flask_app  # noqa: E402


@pytest.fixture()
def client():
    """Yield a Flask test client with TESTING enabled."""
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as test_client:
        yield test_client
