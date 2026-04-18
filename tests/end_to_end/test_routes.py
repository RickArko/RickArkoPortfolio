"""HTTP-first end-to-end tests for public user-visible routes."""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.end_to_end

HTML_PAGES = [
    (
        "/",
        "Rick Arko | Applied AI/ML Builder and Senior Data Scientist",
        "https://rickarko.com/",
        "I build production ML systems and practical AI products that teams can actually use.",
    ),
    (
        "/experience/",
        "Experience | Rick Arko",
        "https://rickarko.com/experience/",
        "Built for operators, product teams, and real production constraints.",
    ),
    (
        "/projects/",
        "Selected Work | Rick Arko",
        "https://rickarko.com/projects/",
        "A mix of private case studies, public experiments, and product-minded builds.",
    ),
    (
        "/blog/",
        "Insights | Rick Arko",
        "https://rickarko.com/blog/",
        "Topics I like writing and speaking about",
    ),
    (
        "/contact/",
        "Connect With Rick Arko",
        "https://rickarko.com/contact/",
        "Open to new opportunities, thoughtful collaborations, and selective consulting.",
    ),
]


@pytest.mark.parametrize(("path", "title", "canonical_url", "snippet"), HTML_PAGES)
def test_public_html_pages_render_expected_contract(
    client,
    path: str,
    title: str,
    canonical_url: str,
    snippet: str,
):
    """Each public HTML page should render the expected content and metadata."""

    response = client.get(path)
    body = response.data.decode()

    assert response.status_code == 200
    assert response.mimetype == "text/html"
    assert f"<title>{title}</title>" in body
    assert f'rel="canonical" href="{canonical_url}"' in body
    assert snippet in body


def test_home_page_exposes_navigation_seo_and_static_assets(client):
    """The homepage should render navigation, SEO tags, and critical asset references."""

    response = client.get("/")
    body = response.data.decode()

    assert 'href="/experience/"' in body
    assert 'href="/projects/"' in body
    assert 'href="/blog/"' in body
    assert 'href="/contact/"' in body
    assert 'name="description"' in body
    assert 'property="og:title"' in body
    assert "application/ld+json" in body
    assert "/static/css/style.css" in body
    assert "/static/images/profile-image.png" in body


def test_projects_page_renders_case_study_content(client):
    """The projects page should surface content loaded from JSON-backed project data."""

    response = client.get("/projects/")
    body = response.data.decode()

    assert "Network Forecasting Platform" in body
    assert "Crypto Market Intelligence App" in body
    assert "Private case study" in body


def test_404_page_renders_branded_fallback_without_traceback(client):
    """Missing pages should render a safe branded fallback page."""

    response = client.get("/definitely-missing")
    body = response.data.decode()

    assert response.status_code == 404
    assert response.mimetype == "text/html"
    assert "Page Not Found" in body
    assert "Traceback" not in body


def test_health_endpoint_returns_expected_json_contract(client):
    """The health endpoint should remain stable for deployment health checks."""

    response = client.get("/health")

    assert response.status_code == 200
    assert response.is_json is True
    assert response.get_json() == {"status": "ok"}


def test_robots_txt_remains_crawlable(client):
    """The robots endpoint should allow crawling and advertise the sitemap."""

    response = client.get("/robots.txt")
    body = response.data.decode()

    assert response.status_code == 200
    assert response.mimetype == "text/plain"
    assert "User-agent: *" in body
    assert "Allow: /" in body
    assert "Sitemap: https://rickarko.com/sitemap.xml" in body


def test_sitemap_xml_lists_primary_pages(client):
    """The sitemap should remain valid XML and enumerate every primary page."""

    response = client.get("/sitemap.xml")
    body = response.data.decode()

    assert response.status_code == 200
    assert response.mimetype == "application/xml"
    assert '<?xml version="1.0" encoding="UTF-8"?>' in body
    assert "<urlset" in body
    assert "https://rickarko.com/" in body
    assert "https://rickarko.com/experience/" in body
    assert "https://rickarko.com/projects/" in body
    assert "https://rickarko.com/blog/" in body
    assert "https://rickarko.com/contact/" in body
