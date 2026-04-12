"""SEO metadata and structured-data helpers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .config import Settings, get_settings
from .content import load_site_profile


@dataclass(frozen=True)
class PageDefinition:
    """Canonical page metadata used for HTML and XML responses."""

    slug: str
    label: str
    path: str
    title: str
    description: str
    keywords: tuple[str, ...]
    og_type: str = "website"
    robots: str = "index,follow"


PAGE_DEFINITIONS = {
    "home": PageDefinition(
        slug="home",
        label="Home",
        path="/",
        title="Rick Arko | AI/ML Consultant, Founder, and Applied AI Builder",
        description=(
            "Rick Arko helps founders and operating teams design, build, and ship "
            "production-ready AI, LLM, and machine learning systems."
        ),
        keywords=(
            "AI consultant",
            "ML consultant",
            "LLM consultant",
            "fractional AI lead",
            "machine learning engineer",
            "AI founder",
        ),
    ),
    "experience": PageDefinition(
        slug="experience",
        label="Experience",
        path="/experience/",
        title="Experience | Rick Arko",
        description=(
            "A track record across forecasting, pricing, recommendation systems, "
            "and production machine learning leadership."
        ),
        keywords=(
            "forecasting",
            "pricing models",
            "machine learning leadership",
            "applied AI",
        ),
    ),
    "projects": PageDefinition(
        slug="projects",
        label="Projects",
        path="/projects/",
        title="Selected Work | Rick Arko",
        description=(
            "Selected consulting-style case studies, experiments, and production "
            "AI/ML work from Rick Arko."
        ),
        keywords=(
            "AI case studies",
            "LLM portfolio",
            "machine learning projects",
            "RAG systems",
        ),
    ),
    "blog": PageDefinition(
        slug="blog",
        label="Insights",
        path="/blog/",
        title="Insights | Rick Arko",
        description=(
            "Writing topics and ideas from the intersection of AI strategy, LLM "
            "systems, forecasting, and product execution."
        ),
        keywords=(
            "AI insights",
            "LLM strategy",
            "RAG evaluation",
            "product engineering",
        ),
    ),
    "contact": PageDefinition(
        slug="contact",
        label="Contact",
        path="/contact/",
        title="Work With Rick Arko",
        description=(
            "Get in touch with Rick Arko about AI strategy, LLM product work, "
            "fractional AI leadership, or hands-on machine learning consulting."
        ),
        keywords=(
            "hire AI consultant",
            "fractional AI leadership",
            "LLM implementation",
            "machine learning advisory",
        ),
    ),
    "404": PageDefinition(
        slug="not-found",
        label="Not Found",
        path="/404/",
        title="Page Not Found | Rick Arko",
        description="The page you requested could not be found.",
        keywords=("404",),
        robots="noindex,follow",
    ),
}


def build_url(path: str, settings: Settings | None = None) -> str:
    resolved_settings = settings or get_settings()
    if path == "/":
        return f"{resolved_settings.site_url}/"
    return f"{resolved_settings.site_url}{path}"


def build_home_schema(settings: Settings | None = None) -> dict[str, Any]:
    resolved_settings = settings or get_settings()
    profile = load_site_profile(resolved_settings)
    same_as = [profile.linkedin_url, profile.github_url, profile.medium_url]

    return {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "Person",
                "@id": f"{resolved_settings.site_url}/#person",
                "name": profile.name,
                "jobTitle": profile.headline,
                "description": profile.short_tagline,
                "url": resolved_settings.site_url,
                "image": resolved_settings.site_image_url,
                "email": profile.email,
                "sameAs": same_as,
                "knowsAbout": [
                    "Large language models",
                    "Retrieval augmented generation",
                    "Applied machine learning",
                    "Forecasting",
                    "Pricing systems",
                    "Recommendation systems",
                    "MLOps",
                ],
            },
            {
                "@type": "ProfessionalService",
                "@id": f"{resolved_settings.site_url}/#service",
                "name": "Rick Arko AI/ML Consulting",
                "url": resolved_settings.site_url,
                "image": resolved_settings.site_image_url,
                "description": (
                    "AI and machine learning consulting for founders and operating "
                    "teams shipping LLM products, decision systems, and production ML."
                ),
                "founder": {"@id": f"{resolved_settings.site_url}/#person"},
                "areaServed": "United States",
                "serviceType": [
                    "AI strategy",
                    "LLM implementation",
                    "Retrieval augmented generation",
                    "Machine learning systems",
                    "Fractional AI leadership",
                ],
                "sameAs": same_as,
            },
            {
                "@type": "WebSite",
                "@id": f"{resolved_settings.site_url}/#website",
                "name": profile.name,
                "url": resolved_settings.site_url,
                "description": profile.short_tagline,
                "publisher": {"@id": f"{resolved_settings.site_url}/#person"},
            },
        ],
    }


def build_page(page_key: str, settings: Settings | None = None) -> dict[str, Any]:
    resolved_settings = settings or get_settings()
    definition = PAGE_DEFINITIONS[page_key]
    page = {
        "slug": definition.slug,
        "label": definition.label,
        "meta_title": definition.title,
        "meta_description": definition.description,
        "meta_keywords": ", ".join(definition.keywords),
        "canonical_url": build_url(definition.path, resolved_settings),
        "robots": definition.robots,
        "og_type": definition.og_type,
        "og_image": resolved_settings.site_image_url,
    }

    if page_key == "home":
        page["schema_graph"] = build_home_schema(resolved_settings)

    return page


def build_sitemap_pages(settings: Settings | None = None) -> list[dict[str, Any]]:
    resolved_settings = settings or get_settings()
    return [
        build_page("home", resolved_settings),
        build_page("experience", resolved_settings),
        build_page("projects", resolved_settings),
        build_page("blog", resolved_settings),
        build_page("contact", resolved_settings),
    ]
