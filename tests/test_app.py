"""Baseline tests for all registered Flask routes."""


# -- Route smoke tests (200 OK) ------------------------------------------


def test_home_returns_200(client):
    """GET / returns 200."""
    response = client.get("/")
    assert response.status_code == 200


def test_home_alt_returns_200(client):
    """GET /home/ returns 200."""
    response = client.get("/home/")
    assert response.status_code == 200


def test_experience_returns_200(client):
    """GET /experience/ returns 200."""
    response = client.get("/experience/")
    assert response.status_code == 200


def test_projects_returns_200(client):
    """GET /projects/ returns 200."""
    response = client.get("/projects/")
    assert response.status_code == 200


def test_blog_returns_200(client):
    """GET /blog/ returns 200."""
    response = client.get("/blog/")
    assert response.status_code == 200


def test_contact_returns_200(client):
    """GET /contact/ returns 200."""
    response = client.get("/contact/")
    assert response.status_code == 200


def test_health_returns_200(client):
    """GET /health returns 200 and JSON body {"status": "ok"}."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_robots_returns_200(client):
    """GET /robots.txt returns crawl directives and sitemap link."""
    response = client.get("/robots.txt")
    body = response.data.decode()
    assert response.status_code == 200
    assert "User-agent: *" in body
    assert "Sitemap: https://rickarko.com/sitemap.xml" in body


def test_sitemap_returns_200(client):
    """GET /sitemap.xml returns an XML sitemap with primary site URLs."""
    response = client.get("/sitemap.xml")
    body = response.data.decode()
    assert response.status_code == 200
    assert "<urlset" in body
    assert "https://rickarko.com/" in body
    assert "https://rickarko.com/projects/" in body


# -- 404 handler -----------------------------------------------------------


def test_404_handler(client):
    """GET /nonexistent triggers the 404 error handler and renders 404.html."""
    response = client.get("/nonexistent")
    assert response.status_code == 404
    body = response.data.decode()
    assert "Page Not Found" in body


# -- Content assertions ----------------------------------------------------


def test_home_content(client):
    """GET / response body contains expected about-section text."""
    response = client.get("/")
    body = response.data.decode()
    assert "Ship AI products that create leverage" in body
    assert "AI/ML Consultant, Founder, and Applied AI Builder" in body
    assert "application/ld+json" in body


def test_projects_content(client):
    """GET /projects/ response body contains project titles from projects.json."""
    response = client.get("/projects/")
    body = response.data.decode()
    assert "Network Forecasting Platform" in body
    assert "Crypto Market Intelligence App" in body
