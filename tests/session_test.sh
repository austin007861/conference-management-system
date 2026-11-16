#!/usr/bin/env bash
# SESS-xxx — session creation, listing, capacity and session registration.
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=config.sh
source ./config.sh
# shellcheck source=helpers.sh
source ./helpers.sh

require_cmd curl
require_cmd jq

if date -u -d "+30 days" +%Y >/dev/null 2>&1; then
  START=$(date -u -d "+30 days" +%Y-%m-%dT10:00:00.000Z)
  END=$(date -u -d "+30 days" +%Y-%m-%dT11:00:00.000Z)
else
  START=$(date -u -v+30d +%Y-%m-%dT10:00:00.000Z)
  END=$(date -u -v+30d +%Y-%m-%dT11:00:00.000Z)
fi

section "Session management and capacity"

login "$ORGANISER_EMAIL" "$ORGANISER_PASSWORD" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SESS-000 organiser session established"

# Resolve the API test conference.
api GET /api/conferences "" "$TEST_TMP_DIR/organiser.jar"
CONF_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_CONFERENCE_TITLE" \
  '[.[] | select(.title == $t)][0].id // empty')

if [ -z "$CONF_ID" ]; then
  skip "SESS-001 session tests" \
    "no conference titled '$TEST_CONFERENCE_TITLE' — run ./tests/conference_test.sh first"
  summary
  exit 0
fi

# SESS-001 — list sessions
api GET /api/sessions "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SESS-001 list sessions"
if printf '%s' "$HTTP_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
  pass "SESS-001 session list is an array"
else
  fail "SESS-001 session list is an array" "got: $HTTP_BODY"
fi

# SESS-002 — create (or reuse) a capacity-1 session
api GET "/api/sessions?conferenceId=$CONF_ID" "" "$TEST_TMP_DIR/organiser.jar"
SESS_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_SESSION_TITLE" \
  '[.[] | select(.title == $t)][0].id // empty')

if [ -n "$SESS_ID" ]; then
  pass "SESS-002 reuse existing test session (id: $SESS_ID)"
else
  SESS_BODY=$(jq -nc --arg c "$CONF_ID" --arg t "$TEST_SESSION_TITLE" --arg s "$START" --arg e "$END" \
    '{conferenceId:$c, title:$t, description:"Created by the Convene API test suite.", startTime:$s, endTime:$e, capacity:1}')
  api POST /api/sessions "$SESS_BODY" "$TEST_TMP_DIR/organiser.jar"
  expect_status 201 "SESS-002 create session as organiser"
  expect_jq '.conferenceId == "'"$CONF_ID"'"' "SESS-002 created session belongs to the test conference"
  expect_jq '.capacity == 1' "SESS-002 created session has the requested capacity"
  SESS_ID=$(printf '%s' "$HTTP_BODY" | jq -r '.id // empty')
fi
export SESS_ID

if [ -z "$SESS_ID" ]; then
  fail "SESS-002 no session id available — remaining session tests cannot run"
  summary
  exit 1
fi

# SESS-003 — session listing is filterable by conference
api GET "/api/sessions?conferenceId=$CONF_ID" "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SESS-003 list sessions filtered by conference"
expect_jq '[.[] | select(.id == "'"$SESS_ID"'")] | length == 1' \
  "SESS-003 the created session is returned for its conference"

# SESS-004 — available sessions report capacity
api GET /api/sessions/available "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SESS-004 list available sessions"
expect_jq '[.[] | select(.sessionId == "'"$SESS_ID"'")][0].capacity == 1' \
  "SESS-004 available session reports capacity 1"

# SESS-005 — first attendee takes the only seat
api POST "/api/conferences/$CONF_ID/register" \
  "{\"conferenceId\":\"$CONF_ID\"}" "$TEST_TMP_DIR/attendee.jar" 2>/dev/null
login "$TEST_ATTENDEE_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/attendee.jar"
api POST "/api/sessions/$SESS_ID/register" "{\"sessionId\":\"$SESS_ID\"}" "$TEST_TMP_DIR/attendee.jar"
if [ "$HTTP_STATUS" = "201" ]; then
  pass "SESS-005 first attendee registered for the session (HTTP 201)"
elif [ "$HTTP_STATUS" = "400" ]; then
  pass "SESS-005 first attendee already registered (reused from an earlier run)"
else
  fail "SESS-005 first attendee could not register for the session" "HTTP $HTTP_STATUS — $HTTP_BODY"
fi

# SESS-006 — capacity is enforced for the second attendee
login "$TEST_ATTENDEE2_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/attendee2.jar"
api POST "/api/sessions/$SESS_ID/register" "{\"sessionId\":\"$SESS_ID\"}" "$TEST_TMP_DIR/attendee2.jar"
expect_status 400 "SESS-006 registration refused when the session is at capacity"
expect_jq '.error | test("capacity"; "i")' "SESS-006 rejection explains the capacity limit"

# SESS-007 — an organiser can list session registrations
api GET "/api/sessions/$SESS_ID/registrations" "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "SESS-007 organiser can list session registrations"

summary
exit $?