"""Application settings and filesystem configuration."""

from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from dotenv import find_dotenv, load_dotenv

PROJECT_SRC_DIR = Path(__file__).resolve().parent.parent
PACKAGE_DIR = Path(__file__).resolve().parent

DEFAULT_SITE_URL = "https://rickarko.com"
DEFAULT_FLASK_ENV = "production"
DEFAULT_PORT = 8080
DEFAULT_STATIC_IMAGE_PATH = "/static/images/profile-image.png"
DEFAULT_DATA_DIR = PROJECT_SRC_DIR / "db"
DEFAULT_TEMPLATE_DIR = PROJECT_SRC_DIR / "templates"
DEFAULT_STATIC_DIR = PROJECT_SRC_DIR / "static"

load_dotenv(find_dotenv(usecwd=True), override=False)


@dataclass(frozen=True)
class Settings:
    """Runtime settings for the Flask application."""

    site_url: str
    flask_env: str
    port: int
    data_dir: Path
    template_dir: Path
    static_dir: Path
    static_image_path: str = DEFAULT_STATIC_IMAGE_PATH

    def __post_init__(self) -> None:
        object.__setattr__(self, "site_url", self.site_url.rstrip("/"))
        object.__setattr__(self, "data_dir", Path(self.data_dir).resolve())
        object.__setattr__(self, "template_dir", Path(self.template_dir).resolve())
        object.__setattr__(self, "static_dir", Path(self.static_dir).resolve())

    @property
    def debug_enabled(self) -> bool:
        return self.flask_env.lower() == "development"

    @property
    def site_image_url(self) -> str:
        return f"{self.site_url}{self.static_image_path}"

    @property
    def home_path(self) -> Path:
        return self.data_dir / "home.json"

    @property
    def experience_path(self) -> Path:
        return self.data_dir / "experience.json"

    @property
    def projects_path(self) -> Path:
        return self.data_dir / "projects.json"


def build_settings(
    *,
    site_url: str = DEFAULT_SITE_URL,
    flask_env: str = DEFAULT_FLASK_ENV,
    port: int = DEFAULT_PORT,
    data_dir: Path | None = None,
    template_dir: Path | None = None,
    static_dir: Path | None = None,
    static_image_path: str = DEFAULT_STATIC_IMAGE_PATH,
) -> Settings:
    """Build an immutable settings object."""

    return Settings(
        site_url=site_url,
        flask_env=flask_env,
        port=port,
        data_dir=data_dir or DEFAULT_DATA_DIR,
        template_dir=template_dir or DEFAULT_TEMPLATE_DIR,
        static_dir=static_dir or DEFAULT_STATIC_DIR,
        static_image_path=static_image_path,
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Load application settings from the environment."""

    return build_settings(
        site_url=os.getenv("SITE_URL", DEFAULT_SITE_URL),
        flask_env=os.getenv("FLASK_ENV", DEFAULT_FLASK_ENV),
        port=int(os.getenv("PORT", str(DEFAULT_PORT))),
        data_dir=Path(os.getenv("APP_DATA_DIR", DEFAULT_DATA_DIR)),
        template_dir=Path(os.getenv("APP_TEMPLATE_DIR", DEFAULT_TEMPLATE_DIR)),
        static_dir=Path(os.getenv("APP_STATIC_DIR", DEFAULT_STATIC_DIR)),
    )


def clear_settings_cache() -> None:
    """Clear the cached settings instance."""

    get_settings.cache_clear()
