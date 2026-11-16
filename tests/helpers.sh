#!/usr/bin/env bash
# Reusable helpers for the Convene API tests.

# Colours (disabled when not writing to a terminal).
if [ -t 1 ]; then
  C_GREEN=$'\033[0;32m'
  C_RED=$'\033[0;31m'
  C_YELLOW=$'\033[0;33m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_GREEN=""; C_RED=""; C_YELLOW=""; C_BOLD=""; C_RESET=""
fi

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# Extra headers applied to the next api() call. Always defined so that
# scripts running under `set -u` can inspect it safely.
EXTRA_HEADERS=()
HTTP_STATUS=""
HTTP_BODY=""

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '%s[PASS]%s %s\n' "$C_GREEN" "$C_RESET" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1"
  if [ -n "${2:-}" ]; then
    printf '       %s\n' "$2"
  fi
}

skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf '%s[SKIP]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"
  if [ -n "${2:-}" ]; then
    printf '       %s\n' "$2"
  fi
}

section() {
  printf '\n%s%s%s\n' "$C_BOLD" "$1" "$C_RESET"
}

summary() {
  printf '\n%s============================%s\n' "$C_BOLD" "$C_RESET"
  printf '%s%s passed%s | %s%s failed%s | %s%s skipped%s\n' \
    "$C_GREEN" "$PASS_COUNT" "$C_RESET" \
    "$C_RED" "$FAIL_COUNT" "$C_RESET" \
    "$C_YELLOW" "$SKIP_COUNT" "$C_RESET"
  printf '%s============================%s\n' "$C_BOLD" "$C_RESET"
  [ "$FAIL_COUNT" -eq 0 ]
}

# Check that a required command exists.
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '%s[FAIL]%s missing required command: %s\n' "$C_RED" "$C_RESET" "$1" >&2
    exit 1
  fi
}

# api METHOD PATH [BODY] [COOKIE_JAR]
# Performs a real HTTP request and writes:
#   HTTP_STATUS  -> numeric status code
#   HTTP_BODY    -> response body
# Extra headers may be passed via EXTRA_HEADERS (array).
api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local jar="${4:-}"

  local args=(-sS -X "$method" -o "$TEST_TMP_DIR/resp.body" -w '%{http_code}'
              -H 'Accept: application/json')

  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' --data "$body")
  fi
  if [ -n "$jar" ]; then
    args+=(-b "$jar" -c "$jar")
  fi
  if [ "${#EXTRA_HEADERS[@]}" -gt 0 ]; then
    local h
    for h in "${EXTRA_HEADERS[@]}"; do
      args+=(-H "$h")
    done
  fi

  HTTP_STATUS=$(curl "${args[@]}" "$BASE_URL$path")
  HTTP_BODY=$(cat "$TEST_TMP_DIR/resp.body")
}

# Assert the last response status matches.
expect_status() {
  local expected="$1"
  local label="$2"
  if [ "$HTTP_STATUS" = "$expected" ]; then
    pass "$label (HTTP $HTTP_STATUS)"
    return 0
  fi
  fail "$label" "expected HTTP $expected, got HTTP $HTTP_STATUS — body: $HTTP_BODY"
  return 1
}

# Assert the last response body is valid JSON.
expect_json() {
  local label="$1"
  if printf '%s' "$HTTP_BODY" | jq -e . >/dev/null 2>&1; then
    pass "$label (valid JSON)"
    return 0
  fi
  fail "$label" "response was not JSON: $HTTP_BODY"
  return 1
}

# Assert a jq expression is truthy against the last response body.
# expect_jq '.success == true' "label"
expect_jq() {
  local filter="$1"
  local label="$2"
  if printf '%s' "$HTTP_BODY" | jq -e "$filter" >/dev/null 2>&1; then
    pass "$label"
    return 0
  fi
  fail "$label" "jq '$filter' did not match — body: $HTTP_BODY"
  return 1
}

# Assert a jq expression is false/null (used for negative tests).
expect_jq_false() {
  local filter="$1"
  local label="$2"
  if printf '%s' "$HTTP_BODY" | jq -e "($filter) | not" >/dev/null 2>&1; then
    pass "$label"
    return 0
  fi
  fail "$label" "jq '$filter' was truthy — body: $HTTP_BODY"
  return 1
}

# Print the last request/response pair for presentation evidence.
show_last() {
  printf '  status : %s\n' "$HTTP_STATUS"
  printf '  body   : %s\n' "$(printf '%s' "$HTTP_BODY" | jq -c . 2>/dev/null || printf '%s' "$HTTP_BODY")"
}

# Log in and store the cookie jar. Sets LOGIN_STATUS / LOGIN_BODY.
login() {
  local email="$1"
  local password="$2"
  local jar="$3"
  EXTRA_HEADERS=('Origin: https://convene-management.pages.dev')
  api POST /api/auth/login "{\"email\":\"$email\",\"password\":\"$password\"}" "$jar"
  EXTRA_HEADERS=()
}