"""Command-line entrypoint for local development."""

from __future__ import annotations

import argparse
from collections.abc import Sequence

from .config import get_settings
from .factory import create_app


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run the Rick Arko portfolio site locally.",
    )
    parser.add_argument("--host", default="0.0.0.0", help="Host interface to bind.")
    parser.add_argument(
        "--port",
        type=int,
        help="Port to bind. Defaults to the configured PORT setting.",
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable Flask debug mode regardless of FLASK_ENV.",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> None:
    settings = get_settings()
    arguments = build_parser().parse_args(argv)
    app = create_app(settings=settings)
    app.run(
        host=arguments.host,
        port=arguments.port or settings.port,
        debug=arguments.debug or settings.debug_enabled,
    )


if __name__ == "__main__":
    main()
