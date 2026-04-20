"""Regression: smoke-test.sh contract must match tests/end_to_end HTML_PAGES.

The bash smoke test runs against the live URL after deploy; the Python e2e
tests run against the in-process Flask client. If these two contracts drift,
we either deploy regressions that local tests would have caught, or roll back
on cosmetic differences that prod did not actually regress.

This test parses the HTML_PAGES array from deployment/bin/smoke-test.sh and
asserts field-for-field equality with tests/end_to_end/test_routes.HTML_PAGES.
"""

from __future__ import annotations

import importlib.util
import re
import sys
from pathlib import Path

import pytest

_ROUTES_PATH = Path(__file__).resolve().parents[1] / "end_to_end" / "test_routes.py"
_spec = importlib.util.spec_from_file_location("_e2e_test_routes", _ROUTES_PATH)
_mod = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = _mod
_spec.loader.exec_module(_mod)
PY_HTML_PAGES = _mod.HTML_PAGES

pytestmark = pytest.mark.regression

SMOKE_SCRIPT = (
    Path(__file__).resolve().parents[2] / "deployment" / "bin" / "smoke-test.sh"
)


def _parse_bash_html_pages(script_text: str) -> list[tuple[str, str, str, str]]:
    """Extract the HTML_PAGES=( ... ) block and split each row on '|'.

    Mirrors smoke-test.sh's parse_html_row(): TITLE may contain '|' characters,
    so we split from both ends (path, then snippet, canonical, title).
    """
    match = re.search(
        r"HTML_PAGES=\(\s*(.*?)\s*\)",
        script_text,
        re.DOTALL,
    )
    assert match, "HTML_PAGES array not found in smoke-test.sh"

    rows: list[tuple[str, str, str, str]] = []
    for raw in match.group(1).splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        assert line.startswith('"') and line.endswith('"'), (
            f"unexpected row syntax in smoke-test.sh: {line!r}"
        )
        content = line[1:-1]

        path, rest = content.split("|", 1)
        without_snippet, snippet = rest.rsplit("|", 1)
        title, canonical = without_snippet.rsplit("|", 1)
        rows.append((path, title, canonical, snippet))

    return rows


def test_smoke_test_html_pages_match_end_to_end_contract():
    bash_rows = _parse_bash_html_pages(SMOKE_SCRIPT.read_text())

    assert bash_rows == PY_HTML_PAGES, (
        "smoke-test.sh HTML_PAGES has drifted from tests/end_to_end HTML_PAGES. "
        "Update both so post-deploy smoke checks match local e2e assertions."
    )


def test_smoke_test_script_is_executable():
    """The deploy workflow invokes the script directly, not via `bash`."""
    assert SMOKE_SCRIPT.exists(), f"missing: {SMOKE_SCRIPT}"
    mode = SMOKE_SCRIPT.stat().st_mode
    assert mode & 0o111, f"smoke-test.sh is not executable (mode={oct(mode)})"
