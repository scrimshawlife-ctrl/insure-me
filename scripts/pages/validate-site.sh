#!/usr/bin/env bash
# Validate the static two-door GitHub Pages site. No secrets. No quote-app tests.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
site="$root/docs/site"

fail() {
  printf 'PAGES_VALIDATE_FAILED: %s\n' "$1" >&2
  exit 1
}

require() {
  [[ -f "$1" ]] || fail "missing $1"
}

require "$site/index.html"
require "$site/exclusive/index.html"
require "$site/broker/index.html"
require "$site/404.html"
require "$site/assets/site.css"
require "$site/.nojekyll"

# Relative assets and door links must exist in the published layout.
grep -q 'href="assets/site.css"' "$site/index.html" || fail "index missing relative stylesheet"
grep -q 'href="exclusive/"' "$site/index.html" || fail "index missing exclusive door"
grep -q 'href="broker/"' "$site/index.html" || fail "index missing broker door"
grep -q 'href="../assets/site.css"' "$site/exclusive/index.html" || fail "exclusive missing stylesheet"
grep -q 'href="../assets/site.css"' "$site/broker/index.html" || fail "broker missing stylesheet"

for page in "$site/index.html" "$site/exclusive/index.html" "$site/broker/index.html"; do
  grep -qi 'live intake is not on these pages' "$page" || fail "$page missing live-intake disclaimer"
  if grep -Eqi 'googletagmanager|google-analytics|gtag\(|facebook\.net|fbevents|hotjar|segment\.com|mixpanel|amplitude|plausible\.io|doubleclick|adservice' "$page"; then
    fail "$page contains a tracker or analytics host"
  fi
  if grep -Eqi '<form|<input|<textarea' "$page"; then
    fail "$page contains a form control"
  fi
  if grep -Eqi '<script' "$page"; then
    fail "$page contains a script tag"
  fi
done

if grep -Eqi 'allstate|compare|compared|comparing|comparison' "$site/exclusive/index.html"; then
  fail "exclusive copy contains forbidden compare or Allstate language"
fi

if grep -Eqi 'allstate' "$site/broker/index.html"; then
  fail "broker copy contains the Allstate mark"
fi

# Board may name gated vendors as uncontracted; it must not claim a live quote.
if grep -Eqi 'start my auto quote|get my quote now' "$site/index.html"; then
  fail "board uses a live-quote CTA"
fi

printf 'PAGES_VALIDATE_OK\n'
