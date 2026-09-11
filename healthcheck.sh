#!/usr/bin/env bash
set -euo pipefail

# URL precedence: CHECK_URL/HEALTHCHECK_URL, then the first non-empty line in
# /ovpn/healthchek.txt (the spelling is kept for compatibility), then Google.
CHECK_URL_FILE="${CHECK_URL_FILE:-/ovpn/healthchek.txt}"
CHECK_URL="${CHECK_URL:-${HEALTHCHECK_URL:-}}"
if [[ -z "$CHECK_URL" && -r "$CHECK_URL_FILE" ]]; then
  CHECK_URL="$(awk 'NF && $1 !~ /^#/ {print $1; exit}' "$CHECK_URL_FILE")"
fi
CHECK_URL="${CHECK_URL:-http://www.google.com}"
PROXY_PORT="${PROXY_PORT:-3128}"

pidof squid >/dev/null
curl --silent --show-error --max-time "${HEALTHCHECK_TIMEOUT:-8}" \
  --proxy "http://127.0.0.1:${PROXY_PORT}" \
  --output /dev/null "$CHECK_URL"
