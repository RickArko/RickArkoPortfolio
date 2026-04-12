"""Unit tests for SEO metadata builders."""

from __future__ import annotations

import pytest

from rickarko_portfolio.seo import (
    build_home_schema,
    build_page,
    build_sitemap_pages,
    build_url,
)

pytestmark = pytest.mark.unit


def test_build_url_handles_root_and_nested_paths(settings):
    """Canonical URL helpers should treat root and nested routes correctly."""

    assert build_url("/", settings) == "https://rickarko.com/"
    assert build_url("/projects/", settings) == "https://rickarko.com/projects/"


def test_home_page_metadata_includes_json_ld(settings):
    """The homepage metadata should include structured data for search engines."""

    page = build_page("home", settings)

    assert page["canonical_url"] == "https://rickarko.com/"
    assert page["meta_title"].startswith("Rick Arko |")
    assert "schema_graph" in page


def test_non_home_pages_do_not_embed_schema_graph(settings):
    """Only the homepage should include the large structured-data graph."""

    page = build_page("projects", settings)

    assert page["canonical_url"] == "https://rickarko.com/projects/"
    assert "schema_graph" not in page


def test_home_schema_uses_profile_links(settings):
    """The schema graph should include the social links from profile content."""

    schema = build_home_schema(settings)
    person = schema["@graph"][0]

    assert person["@type"] == "Person"
    assert "https://www.linkedin.com/in/rickarko" in person["sameAs"]
    assert "https://github.com/RickArko" in person["sameAs"]


def test_sitemap_pages_cover_core_routes(settings):
    """The sitemap helper should list each primary public page exactly once."""

    pages = build_sitemap_pages(settings)
    urls = {page["canonical_url"] for page in pages}

    assert urls == {
        "https://rickarko.com/",
        "https://rickarko.com/experience/",
        "https://rickarko.com/projects/",
        "https://rickarko.com/blog/",
        "https://rickarko.com/contact/",
    }
