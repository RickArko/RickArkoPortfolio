"""HTTP-first end-to-end tests for public user-visible routes."""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.end_to_end

HTML_PAGES = [
    (
        "/",
        "Rick Arko | AI/ML Builder, Senior Data Scientist, ML Engineer",
        "https://rickarko.com/",
        "I build AI/ML solutions that businesses can use to scale responsibly.",
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
        "/contact/",
        "Connect With Rick Arko",
        "https://rickarko.com/contact/",
        "IC roles, hands-on technical leadership, and selective consulting.",
    ),
    (
        "/sign-in/",
        "Sign In | Rick Arko",
        "https://rickarko.com/sign-in/",
        "A separate space from the public site, used for active engagements",
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
    assert 'href="/sign-in/"' in body
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


def test_sign_in_page_renders_form_contract(client):
    """The sign-in page should expose the expected minimal form fields."""

    response = client.get("/sign-in/")
    body = response.data.decode()

    assert response.status_code == 200
    assert 'method="post"' in body
    assert 'name="username"' in body
    assert 'type="password"' in body
    assert "Remember me" in body
    assert 'name="robots" content="noindex,follow"' in body


def test_sign_in_rejects_missing_fields(client):
    """Empty submissions should re-render the form with a validation error."""

    response = client.post("/sign-in/", data={"username": "", "password": ""})
    body = response.data.decode()

    assert response.status_code == 200
    assert "Enter both a username and password to continue." in body


def test_sign_in_rejects_bad_credentials(client):
    """Wrong credentials should re-render the form with an error message."""

    response = client.post(
        "/sign-in/",
        data={"username": "rickarko", "password": "wrong"},
    )
    body = response.data.decode()

    assert response.status_code == 200
    assert "Those credentials did not match." in body


def test_sign_in_with_valid_credentials_redirects_to_blog(client):
    """Valid credentials should redirect to /blog/ by default."""

    response = client.post(
        "/sign-in/",
        data={"username": "rickarko", "password": "IamRickarko"},
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/blog/")


def test_sign_in_honors_safe_next_parameter(client):
    """A safe relative next= parameter should drive the post-login redirect."""

    response = client.post(
        "/sign-in/?next=/blog/",
        data={"username": "rickarko", "password": "IamRickarko"},
    )

    assert response.status_code == 302
    assert response.headers["Location"].endswith("/blog/")


def test_sign_in_ignores_offsite_next_parameter(client):
    """An off-site next= must not be used as the redirect target."""

    response = client.post(
        "/sign-in/?next=https://evil.example.com/steal",
        data={"username": "rickarko", "password": "IamRickarko"},
    )

    assert response.status_code == 302
    assert "evil.example.com" not in response.headers["Location"]
    assert response.headers["Location"].endswith("/blog/")


def test_blog_redirects_unauthed_visitor_to_sign_in(client):
    """The Insights page should be gated behind sign-in."""

    response = client.get("/blog/")

    assert response.status_code == 302
    location = response.headers["Location"]
    assert "/sign-in/" in location
    assert "next=" in location and "/blog/" in location


def test_blog_renders_for_authed_client(authed_client):
    """An authenticated session should reach the Insights page."""

    response = authed_client.get("/blog/")
    body = response.data.decode()

    assert response.status_code == 200
    assert "<title>Insights | Rick Arko</title>" in body


def test_sign_out_clears_session_and_redirects_home(authed_client):
    """Signing out should drop the session and bounce to home."""

    response = authed_client.get("/sign-out/")
    assert response.status_code == 302
    assert response.headers["Location"].endswith("/")

    follow_up = authed_client.get("/blog/")
    assert follow_up.status_code == 302
    assert "/sign-in/" in follow_up.headers["Location"]


def test_authed_navbar_shows_sign_out(authed_client):
    """When signed in, the navbar should expose a sign-out link, not sign-in."""

    response = authed_client.get("/")
    body = response.data.decode()

    assert ">Sign out</a>" in body
    assert ">Sign in</a>" not in body


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
