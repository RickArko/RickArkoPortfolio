"""Flask application factory."""

from __future__ import annotations

import hmac
from datetime import date
from functools import wraps
from typing import Any, Mapping
from urllib.parse import urlparse

from flask import (
    Flask,
    Response,
    redirect,
    render_template,
    request,
    session,
    url_for,
)

from .config import Settings, get_settings
from .content import (
    load_experience_content,
    load_home_content,
    load_projects_content,
    load_site_profile,
)
from .seo import build_page, build_sitemap_pages

INSIGHTS_AUTH_SESSION_KEY = "insights_authed"


def _is_insights_authed() -> bool:
    return bool(session.get(INSIGHTS_AUTH_SESSION_KEY))


def _safe_next_target(candidate: str | None, fallback: str) -> str:
    """Allow only same-host relative paths so `next` cannot redirect off-site."""

    if not candidate:
        return fallback
    parsed = urlparse(candidate)
    if parsed.scheme or parsed.netloc:
        return fallback
    if not candidate.startswith("/"):
        return fallback
    return candidate


def create_app(
    *,
    settings: Settings | None = None,
    config_overrides: Mapping[str, Any] | None = None,
) -> Flask:
    """Create and configure the Flask application."""

    resolved_settings = settings or get_settings()
    app = Flask(
        __name__,
        template_folder=str(resolved_settings.template_dir),
        static_folder=str(resolved_settings.static_dir),
        static_url_path="/static",
    )
    app.config.from_mapping(SETTINGS=resolved_settings)
    app.secret_key = resolved_settings.secret_key
    if config_overrides:
        app.config.update(config_overrides)

    def render_page(
        template_name: str,
        page_key: str,
        *,
        context: dict[str, Any] | None = None,
        status: int = 200,
    ) -> tuple[str, int]:
        return (
            render_template(
                template_name,
                context=context or {},
                page=build_page(page_key, resolved_settings),
                site=load_site_profile(resolved_settings),
                current_year=date.today().year,
                insights_authed=_is_insights_authed(),
            ),
            status,
        )

    def require_insights_auth(view):
        @wraps(view)
        def wrapper(*args, **kwargs):
            if not _is_insights_authed():
                return redirect(url_for("sign_in", next=request.path), code=302)
            return view(*args, **kwargs)

        return wrapper

    @app.errorhandler(404)
    def not_found(_error: Exception) -> tuple[str, int]:
        return render_page("404.html", "404", status=404)

    @app.route("/")
    @app.route("/home/")
    def home() -> tuple[str, int]:
        return render_page(
            "home.html",
            "home",
            context=load_home_content(resolved_settings),
        )

    @app.route("/experience/")
    def experience() -> tuple[str, int]:
        return render_page(
            "experience.html",
            "experience",
            context=load_experience_content(resolved_settings),
        )

    @app.route("/blog/")
    @require_insights_auth
    def blog() -> tuple[str, int]:
        return render_page(
            "blog.html",
            "blog",
            context=load_home_content(resolved_settings),
        )

    @app.route("/projects/")
    def projects() -> tuple[str, int]:
        return render_page(
            "projects.html",
            "projects",
            context=load_projects_content(resolved_settings),
        )

    @app.route("/contact/")
    def contact() -> tuple[str, int]:
        return render_page(
            "contact.html",
            "contact",
            context=load_home_content(resolved_settings),
        )

    @app.route("/sign-in/", methods=["GET", "POST"])
    def sign_in():
        home_content = load_home_content(resolved_settings)
        next_target = _safe_next_target(request.values.get("next"), url_for("blog"))
        context: dict[str, Any] = {
            "username": "",
            "remember": False,
            "status": None,
            "message": None,
            "next": next_target,
            "sign_in": home_content.get("sign_in", {}),
        }

        if _is_insights_authed() and request.method == "GET":
            return redirect(next_target, code=302)

        if request.method == "POST":
            username = request.form.get("username", "").strip()
            password = request.form.get("password", "")
            remember = request.form.get("remember") == "on"

            context.update(username=username, remember=remember)

            if not username or not password:
                context.update(
                    status="error",
                    message="Enter both a username and password to continue.",
                )
            else:
                expected_user = resolved_settings.insights_username
                expected_pw = resolved_settings.insights_password
                user_ok = hmac.compare_digest(username, expected_user)
                pw_ok = hmac.compare_digest(password, expected_pw)
                if user_ok and pw_ok:
                    session.clear()
                    session[INSIGHTS_AUTH_SESSION_KEY] = True
                    session.permanent = remember
                    return redirect(next_target, code=302)
                context.update(
                    status="error",
                    message="Those credentials did not match. Try again.",
                )

        return render_page("sign-in.html", "sign_in", context=context)

    @app.route("/sign-out/", methods=["GET", "POST"])
    def sign_out():
        session.clear()
        return redirect(url_for("home"), code=302)

    @app.route("/robots.txt")
    def robots() -> Response:
        if resolved_settings.robots_noindex:
            body = "\n".join(["User-agent: *", "Disallow: /", ""])
        else:
            body = "\n".join(
                [
                    "User-agent: *",
                    "Allow: /",
                    f"Sitemap: {resolved_settings.site_url}/sitemap.xml",
                    "",
                ]
            )
        return Response(body, mimetype="text/plain")

    @app.route("/sitemap.xml")
    def sitemap() -> Response:
        return Response(
            render_template(
                "sitemap.xml",
                pages=build_sitemap_pages(resolved_settings),
                today=date.today().isoformat(),
            ),
            mimetype="application/xml",
        )

    @app.route("/health")
    def health() -> dict[str, str]:
        return {"status": "ok"}

    return app
