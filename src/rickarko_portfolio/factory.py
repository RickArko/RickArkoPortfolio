"""Flask application factory."""

from __future__ import annotations

from datetime import date
from typing import Any, Mapping

from flask import Flask, Response, render_template, request

from .config import Settings, get_settings
from .content import (
    load_experience_content,
    load_home_content,
    load_projects_content,
    load_site_profile,
)
from .seo import build_page, build_sitemap_pages


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
            ),
            status,
        )

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
    def sign_in() -> tuple[str, int]:
        home_content = load_home_content(resolved_settings)
        context: dict[str, Any] = {
            "email": "",
            "remember": False,
            "status": None,
            "message": None,
            "sign_in": home_content.get("sign_in", {}),
        }

        if request.method == "POST":
            email = request.form.get("email", "").strip()
            password = request.form.get("password", "")
            remember = request.form.get("remember") == "on"

            context.update(email=email, remember=remember)

            if not email or not password:
                context.update(
                    status="error",
                    message="Enter both an email and password to continue.",
                )
            else:
                context.update(
                    status="success",
                    message=(
                        "Sign-in received. I'll follow up by email — use the "
                        "contact page for anything time-sensitive."
                    ),
                )

        return render_page("sign-in.html", "sign_in", context=context)

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
