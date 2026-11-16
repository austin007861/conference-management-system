#!/usr/bin/env bash
# SPK-xxx — speaker records and speaker-to-session assignment.
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=config.sh
source ./config.sh
# shellcheck source=helpers.sh
source ./helpers.sh

require_cmd curl
require_cmd jq

section "Speaker management"

login "$ORGANISER_EMAIL" "$ORGANISER_PASSWORD" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SPK-000 organiser session established"

# SPK-001 — list speakers
api GET /api/speakers "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SPK-001 list speakers"
if printf '%s' "$HTTP_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
  pass "SPK-001 speaker list is an array"
else
  fail "SPK-001 speaker list is an array" "got: $HTTP_BODY"
fi

# SPK-002 — create (or reuse) a test speaker record
api GET /api/speakers "" "$TEST_TMP_DIR/organiser.jar"
SPK_ID=$(printf '%s' "$HTTP_BODY" | jq -r \
  '[.[] | select(.bio | test("Convene API test suite"))][0].id // empty')

if [ -n "$SPK_ID" ]; then
  pass "SPK-002 reuse existing test speaker (id: $SPK_ID)"
else
  api POST /api/speakers \
    '{"bio":"Created by the Convene API test suite."}' \
    "$TEST_TMP_DIR/organiser.jar"
  expect_status 201 "SPK-002 create speaker as organiser"
  expect_jq '.bio == "Created by the Convene API test suite."' \
    "SPK-002 created speaker stores the supplied bio"
  SPK_ID=$(printf '%s' "$HTTP_BODY" | jq -r '.id // empty')
fi
export SPK_ID

if [ -z "$SPK_ID" ]; then
  fail "SPK-002 no speaker id available — assignment tests cannot run"
  summary
  exit 1
fi

# SPK-003 — an attendee role cannot create speakers
api POST /api/auth/signup \
  "{\"name\":\"Test Attendee\",\"email\":\"$TEST_ATTENDEE_EMAIL\",\"password\":\"$TEST_ATTENDEE_PASSWORD\",\"role\":\"attendee\"}"
if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "409" ]; then
  pass "SPK-003 test attendee account available"
else
  fail "SPK-003 could not prepare a test attendee account" "HTTP $HTTP_STATUS — $HTTP_BODY"
fi

login "$TEST_ATTENDEE_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/attendee.jar"
api POST /api/speakers '{"bio":"Should be rejected"}' "$TEST_TMP_DIR/attendee.jar"
expect_status 403 "SPK-003 attendee is forbidden from creating a speaker"

# SPK-004 — assign the speaker to a session
api GET /api/conferences "" "$TEST_TMP_DIR/organiser.jar"
CONF_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_CONFERENCE_TITLE" \
  '[.[] | select(.title == $t)][0].id // empty')

api GET "/api/sessions?conferenceId=$CONF_ID" "" "$TEST_TMP_DIR/organiser.jar"
SESS_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_SESSION_TITLE" \
  '[.[] | select(.title == $t)][0].id // empty')

if [ -z "$SESS_ID" ]; then
  skip "SPK-004 assign speaker to session" \
    "no test session found — run ./tests/session_test.sh first"
else
  api POST /api/session-speakers \
    "{\"sessionId\":\"$SESS_ID\",\"speakerId\":\"$SPK_ID\",\"speakerRole\":\"speaker\"}" \
    "$TEST_TMP_DIR/organiser.jar"
  if [ "$HTTP_STATUS" = "201" ]; then
    pass "SPK-004 speaker assigned to the session (HTTP 201)"
    expect_jq '.speakerId == "'"$SPK_ID"'"' "SPK-004 assignment references the created speaker"
    expect_jq '.sessionId == "'"$SESS_ID"'"' "SPK-004 assignment references the test session"
  elif [ "$HTTP_STATUS" = "409" ]; then
    pass "SPK-004 speaker was already assigned (reused from an earlier run)"
  else
    fail "SPK-004 speaker assignment failed" "HTTP $HTTP_STATUS — $HTTP_BODY"
  fi
fi

# SPK-005 — conference detail exposes the assigned speaker
if [ -n "${CONF_ID:-}" ] && [ -n "${SESS_ID:-}" ]; then
  api GET "/api/conferences/$CONF_ID" "" "$TEST_TMP_DIR/organiser.jar"
  expect_jq '[.speakers[] | select(.id == "'"$SPK_ID"'")] | length > 0' \
    "SPK-005 conference detail lists the assigned speaker"
fi

summary
exit $?