"""WSGI entrypoint for application servers."""

from .factory import create_app

app = create_app()
application = app
