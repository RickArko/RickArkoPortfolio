import json
from datetime import date
from functools import lru_cache

from flask import Flask, Response, render_template

import constants

app = Flask(__name__)

SITE_URL = "https://rickarko.com"
SITE_IMAGE = f"{SITE_URL}/static/images/profile-image.png"

PAGE_CONFIG = {
    "home": {
        "slug": "home",
        "label": "Home",
        "path": "/",
        "title": "Rick Arko | AI/ML Consultant, Founder, and Applied AI Builder",
        "description": (
            "Rick Arko helps founders and operating teams design, build, and ship "
            "production-ready AI, LLM, and machine learning systems."
        ),
        "keywords": [
            "AI consultant",
            "ML consultant",
            "LLM consultant",
            "fractional AI lead",
            "machine learning engineer",
            "AI founder",
        ],
        "og_type": "website",
    },
    "experience": {
        "slug": "experience",
        "label": "Experience",
        "path": "/experience/",
        "title": "Experience | Rick Arko",
        "description": (
            "A track record across forecasting, pricing, recommendation systems, "
            "and production machine learning leadership."
        ),
        "keywords": [
            "forecasting",
            "pricing models",
            "machine learning leadership",
            "applied AI",
        ],
        "og_type": "website",
    },
    "projects": {
        "slug": "projects",
        "label": "Projects",
        "path": "/projects/",
        "title": "Selected Work | Rick Arko",
        "description": (
            "Selected consulting-style case studies, experiments, and production "
            "AI/ML work from Rick Arko."
        ),
        "keywords": [
            "AI case studies",
            "LLM portfolio",
            "machine learning projects",
            "RAG systems",
        ],
        "og_type": "website",
    },
    "blog": {
        "slug": "blog",
        "label": "Insights",
        "path": "/blog/",
        "title": "Insights | Rick Arko",
        "description": (
            "Writing topics and ideas from the intersection of AI strategy, LLM "
            "systems, forecasting, and product execution."
        ),
        "keywords": [
            "AI insights",
            "LLM strategy",
            "RAG evaluation",
            "product engineering",
        ],
        "og_type": "website",
    },
    "contact": {
        "slug": "contact",
        "label": "Contact",
        "path": "/contact/",
        "title": "Work With Rick Arko",
        "description": (
            "Get in touch with Rick Arko about AI strategy, LLM product work, "
            "fractional AI leadership, or hands-on machine learning consulting."
        ),
        "keywords": [
            "hire AI consultant",
            "fractional AI leadership",
            "LLM implementation",
            "machine learning advisory",
        ],
        "og_type": "website",
    },
    "404": {
        "slug": "not-found",
        "label": "Not Found",
        "path": "/404/",
        "title": "Page Not Found | Rick Arko",
        "description": "The page you requested could not be found.",
        "keywords": ["404"],
        "og_type": "website",
        "robots": "noindex,follow",
    },
}


@lru_cache(maxsize=None)
def load_json(path):
    with open(path, encoding="utf-8") as file:
        return json.load(file)


def build_url(path):
    if path == "/":
        return f"{SITE_URL}/"
    return f"{SITE_URL}{path}"


def build_page(page_key):
    config = PAGE_CONFIG[page_key]
    page = {
        "slug": config["slug"],
        "label": config["label"],
        "meta_title": config["title"],
        "meta_description": config["description"],
        "meta_keywords": ", ".join(config["keywords"]),
        "canonical_url": build_url(config["path"]),
        "robots": config.get("robots", "index,follow"),
        "og_type": config.get("og_type", "website"),
        "og_image": SITE_IMAGE,
    }

    if config["slug"] == "home":
        page["schema_graph"] = build_home_schema()

    return page


def build_home_schema():
    profile = load_json(constants.HOME_PATH)["profile"]
    same_as = [profile["linkedin_url"], profile["github_url"], profile["medium_url"]]

    return {
        "@context": "https://schema.org",
        "@graph": [
            {
                "@type": "Person",
                "@id": f"{SITE_URL}/#person",
                "name": profile["name"],
                "jobTitle": profile["headline"],
                "description": profile["short_tagline"],
                "url": SITE_URL,
                "image": SITE_IMAGE,
                "email": profile["email"],
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
                "@id": f"{SITE_URL}/#service",
                "name": "Rick Arko AI/ML Consulting",
                "url": SITE_URL,
                "image": SITE_IMAGE,
                "description": (
                    "AI and machine learning consulting for founders and operating "
                    "teams shipping LLM products, decision systems, and production ML."
                ),
                "founder": {"@id": f"{SITE_URL}/#person"},
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
                "@id": f"{SITE_URL}/#website",
                "name": profile["name"],
                "url": SITE_URL,
                "description": profile["short_tagline"],
                "publisher": {"@id": f"{SITE_URL}/#person"},
            },
        ],
    }


def get_site():
    return load_json(constants.HOME_PATH)["profile"]


def render_page(template_name, page_key, context=None, status=200):
    return (
        render_template(
            template_name,
            context=context or {},
            page=build_page(page_key),
            site=get_site(),
            current_year=date.today().year,
        ),
        status,
    )


@app.errorhandler(404)
def not_found(_error):
    return render_page("404.html", "404", status=404)


@app.route("/")
@app.route("/home/")
def home():
    return render_page("home.html", "home", context=load_json(constants.HOME_PATH))


@app.route("/experience/")
def experience():
    return render_page(
        "experience.html",
        "experience",
        context=load_json(constants.EXPERIENCE_PATH),
    )


@app.route("/blog/")
def blog():
    return render_page("blog.html", "blog", context=load_json(constants.HOME_PATH))


@app.route("/projects/")
def projects():
    return render_page(
        "projects.html",
        "projects",
        context=load_json(constants.PROJECT_PATH),
    )


@app.route("/contact/")
def contact():
    return render_page("contact.html", "contact", context=load_json(constants.HOME_PATH))


@app.route("/robots.txt")
def robots():
    body = "\n".join(
        [
            "User-agent: *",
            "Allow: /",
            f"Sitemap: {SITE_URL}/sitemap.xml",
            "",
        ]
    )
    return Response(body, mimetype="text/plain")


@app.route("/sitemap.xml")
def sitemap():
    pages = [
        build_page("home"),
        build_page("experience"),
        build_page("projects"),
        build_page("blog"),
        build_page("contact"),
    ]
    return Response(
        render_template(
            "sitemap.xml",
            pages=pages,
            today=date.today().isoformat(),
        ),
        mimetype="application/xml",
    )


@app.route("/health")
def health():
    return {"status": "ok"}


application = app

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)
