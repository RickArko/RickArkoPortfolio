#!/usr/bin/env bash
# Post-deploy HTTP contract smoke test.
#
# Usage: smoke-test.sh <BASE_URL>
#        BASE_URL has no trailing slash, e.g. https://rickarko.com
#
# Exits non-zero if any route fails its contract. Each route is retried
# with the same cadence as the App Runner deploy poll so a warming
# service does not produce a spurious red.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
source "$SCRIPT_DIR/common.sh"

readonly MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-30}"
readonly SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-10}"

# -----------------------------------------------------------------------------
# HTML contract table. KEEP IN SYNC with tests/end_to_end/test_routes.py::HTML_PAGES.
# Parity is enforced by tests/regression/test_smoke_contract.py.
#
# Format per line: PATH|TITLE|CANONICAL|SNIPPET
# Field separator is '|' — none of the current fields contain a pipe.
# -----------------------------------------------------------------------------
readonly HTML_PAGES=(
    "/|Rick Arko | Applied AI/ML Builder and Senior Data Scientist|https://rickarko.com/|I build production ML systems and practical AI products that teams can actually use."
    "/experience/|Experience | Rick Arko|https://rickarko.com/experience/|Built for operators, product teams, and real production constraints."
    "/projects/|Selected Work | Rick Arko|https://rickarko.com/projects/|A mix of private case studies, public experiments, and product-minded builds."
    "/blog/|Insights | Rick Arko|https://rickarko.com/blog/|Topics I like writing and speaking about"
    "/contact/|Connect With Rick Arko|https://rickarko.com/contact/|Open to new opportunities, thoughtful collaborations, and selective consulting."
)

readonly SITEMAP_URLS=(
    "https://rickarko.com/"
    "https://rickarko.com/experience/"
    "https://rickarko.com/projects/"
    "https://rickarko.com/blog/"
    "https://rickarko.com/contact/"
)

usage() {
    cat <<'USAGE'
Usage: smoke-test.sh <BASE_URL>

Validates the public HTTP contract against BASE_URL.
BASE_URL must have no trailing slash (e.g. https://rickarko.com).

Environment overrides:
  SMOKE_MAX_ATTEMPTS  retries per route (default 30)
  SMOKE_SLEEP_SECONDS sleep between retries (default 10)
USAGE
}

if [[ $# -ne 1 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    [[ $# -eq 1 ]] && exit 0
    exit 2
fi

require_cmd curl

BASE_URL="${1%/}"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Splits an HTML_PAGES entry on '|' into 4 fields, tolerating embedded '|' in
# the TITLE field by splitting from both ends.
parse_html_row() {
    local row="$1"
    local path rest without_snippet title canonical snippet

    path="${row%%|*}"
    rest="${row#*|}"
    snippet="${rest##*|}"
    without_snippet="${rest%|*}"
    canonical="${without_snippet##*|}"
    title="${without_snippet%|*}"

    printf "%s\n%s\n%s\n%s\n" "$path" "$title" "$canonical" "$snippet"
}

fetch_with_retry() {
    local url="$1"
    local tmp="$2"
    local attempt=1
    local status=""

    while (( attempt <= MAX_ATTEMPTS )); do
        status="$(curl -sS -L -o "$tmp" -w '%{http_code}' "$url" || true)"
        if [[ "$status" == "200" ]]; then
            return 0
        fi
        warn "  attempt ${attempt}/${MAX_ATTEMPTS}: ${url} → ${status:-error}; sleeping ${SLEEP_SECONDS}s"
        sleep "$SLEEP_SECONDS"
        (( attempt++ ))
    done

    error "giving up on ${url} after ${MAX_ATTEMPTS} attempts (last status: ${status:-error})"
    return 1
}

content_type() {
    curl -sS -L -o /dev/null -w '%{content_type}' "$1" || true
}

assert_contains() {
    local label="$1"
    local file="$2"
    local needle="$3"

    if ! grep -Fq -- "$needle" "$file"; then
        error "  [$label] missing expected content: $needle"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Route checks
# -----------------------------------------------------------------------------

failures=0
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

section "Smoke test against $BASE_URL"

# HTML pages
for row in "${HTML_PAGES[@]}"; do
    mapfile -t parsed < <(parse_html_row "$row")
    path="${parsed[0]}"
    title="${parsed[1]}"
    canonical="${parsed[2]}"
    snippet="${parsed[3]}"

    url="${BASE_URL}${path}"
    info "→ $url"

    body_file="${work_dir}/body$(echo "$path" | tr '/' '_')"
    if ! fetch_with_retry "$url" "$body_file"; then
        (( failures++ ))
        continue
    fi

    ctype="$(content_type "$url")"
    if [[ "$ctype" != text/html* ]]; then
        error "  content-type not text/html: $ctype"
        (( failures++ ))
    fi

    assert_contains "$path" "$body_file" "<title>${title}</title>"         || (( failures++ ))
    assert_contains "$path" "$body_file" "rel=\"canonical\" href=\"${canonical}\"" || (( failures++ ))
    assert_contains "$path" "$body_file" "$snippet"                        || (( failures++ ))
done

# /health
info "→ ${BASE_URL}/health"
health_file="${work_dir}/health.json"
if fetch_with_retry "${BASE_URL}/health" "$health_file"; then
    if ! grep -Fq '"status":"ok"' "$health_file" && ! grep -Fq '"status": "ok"' "$health_file"; then
        error "  /health did not return {\"status\":\"ok\"}"
        (( failures++ ))
    fi
else
    (( failures++ ))
fi

# /robots.txt
info "→ ${BASE_URL}/robots.txt"
robots_file="${work_dir}/robots.txt"
if fetch_with_retry "${BASE_URL}/robots.txt" "$robots_file"; then
    assert_contains "robots.txt" "$robots_file" "User-agent: *" || (( failures++ ))
    assert_contains "robots.txt" "$robots_file" "Sitemap:"     || (( failures++ ))
else
    (( failures++ ))
fi

# /sitemap.xml
info "→ ${BASE_URL}/sitemap.xml"
sitemap_file="${work_dir}/sitemap.xml"
if fetch_with_retry "${BASE_URL}/sitemap.xml" "$sitemap_file"; then
    assert_contains "sitemap.xml" "$sitemap_file" '<?xml version="1.0" encoding="UTF-8"?>' || (( failures++ ))
    assert_contains "sitemap.xml" "$sitemap_file" "<urlset"                                 || (( failures++ ))
    for url in "${SITEMAP_URLS[@]}"; do
        assert_contains "sitemap.xml" "$sitemap_file" "$url" || (( failures++ ))
    done
else
    (( failures++ ))
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

if (( failures > 0 )); then
    error "Smoke test failed with ${failures} contract violation(s)."
    exit 1
fi

info "Smoke test passed: all routes match the expected contract."
