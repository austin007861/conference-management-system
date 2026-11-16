#!/usr/bin/env bash
# REG-xxx — attendee registration, duplicate prevention and capacity enforcement.
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=config.sh
source ./config.sh
# shellcheck source=helpers.sh
source ./helpers.sh

require_cmd curl
require_cmd jq

if date -u -d "+30 days" +%Y >/dev/null 2>&1; then
  START=$(date -u -d "+30 days" +%Y-%m-%dT09:00:00.000Z)
  END=$(date -u -d "+32 days" +%Y-%m-%dT17:00:00.000Z)
else
  START=$(date -u -v+30d +%Y-%m-%dT09:00:00.000Z)
  END=$(date -u -v+32d +%Y-%m-%dT17:00:00.000Z)
fi

section "Attendee registration"

# REG-001 — create a test attendee (public signup allows attendee/speaker only)
SIGNUP_BODY="{\"name\":\"Test Attendee\",\"email\":\"$TEST_ATTENDEE_EMAIL\",\"password\":\"$TEST_ATTENDEE_PASSWORD\",\"role\":\"attendee\"}"
api POST /api/auth/signup "$SIGNUP_BODY"
if [ "$HTTP_STATUS" = "201" ]; then
  pass "REG-001 test attendee created via public signup"
elif [ "$HTTP_STATUS" = "409" ]; then
  pass "REG-001 test attendee already exists (reused)"
else
  fail "REG-001 test attendee could not be created" "HTTP $HTTP_STATUS — $HTTP_BODY"
fi

# REG-001b — public signup must refuse the admin role
ADMIN_SIGNUP="{\"name\":\"Should Fail\",\"email\":\"should.fail@convene.com\",\"password\":\"$TEST_ATTENDEE_PASSWORD\",\"role\":\"admin\"}"
api POST /api/auth/signup "$ADMIN_SIGNUP"
expect_status 400 "REG-001 public signup rejects the admin role"

# REG-002 — attendee login
login "$TEST_ATTENDEE_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/attendee.jar"
expect_status 200 "REG-002 attendee login succeeds"
expect_jq '.data.role == "attendee"' "REG-002 attendee receives the attendee role"

# REG-003 — attendee registers for the API test conference
api GET /api/conferences/available "" "$TEST_TMP_DIR/attendee.jar"
expect_status 200 "REG-003 attendee can read available conferences"

TARGET_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_CONFERENCE_TITLE" \
  '[.[] | select(.title == $t and .registrationOpen == true)][0].conferenceId // empty')

if [ -z "$TARGET_ID" ]; then
  skip "REG-003 attendee registration" \
    "no open conference titled '$TEST_CONFERENCE_TITLE' — run ./tests/conference_test.sh first"
else
  api POST "/api/conferences/$TARGET_ID/register" \
    "{\"conferenceId\":\"$TARGET_ID\"}" "$TEST_TMP_DIR/attendee.jar"
  if [ "$HTTP_STATUS" = "201" ]; then
    pass "REG-003 attendee registered for a conference (HTTP 201)"
  elif [ "$HTTP_STATUS" = "400" ]; then
    pass "REG-003 attendee was already registered (reused from an earlier run)"
  else
    fail "REG-003 attendee registration failed" "HTTP $HTTP_STATUS — $HTTP_BODY"
  fi

  # REG-004 — duplicate registration is rejected
  api POST "/api/conferences/$TARGET_ID/register" \
    "{\"conferenceId\":\"$TARGET_ID\"}" "$TEST_TMP_DIR/attendee.jar"
  expect_status 400 "REG-004 duplicate conference registration is rejected"
  expect_jq '.error | test("already registered"; "i")' \
    "REG-004 rejection explains the duplicate"
fi

# REG-005 — capacity enforcement
login "$ORGANISER_EMAIL" "$ORGANISER_PASSWORD" "$TEST_TMP_DIR/organiser.jar"

CAP_SIGNUP_2="{\"name\":\"Test Attendee Two\",\"email\":\"$TEST_ATTENDEE2_EMAIL\",\"password\":\"$TEST_ATTENDEE_PASSWORD\",\"role\":\"attendee\"}"
api POST /api/auth/signup "$CAP_SIGNUP_2"
if [ "$HTTP_STATUS" = "201" ]; then
  pass "REG-005 second test attendee created"
elif [ "$HTTP_STATUS" = "409" ]; then
  pass "REG-005 second test attendee already exists (reused)"
else
  fail "REG-005 second test attendee could not be created" "HTTP $HTTP_STATUS — $HTTP_BODY"
fi

api GET /api/conferences "" "$TEST_TMP_DIR/organiser.jar"
CAP_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_CAPACITY_CONFERENCE_TITLE" \
  '[.[] | select(.title == $t)][0].id // empty')

if [ -z "$CAP_ID" ]; then
  CAP_BODY=$(jq -nc --arg t "$TEST_CAPACITY_CONFERENCE_TITLE" --arg s "$START" --arg e "$END" \
    '{title:$t, description:"Capacity-limited conference for API tests.", startDate:$s, endDate:$e, capacity:1, status:"upcoming"}')
  api POST /api/conferences "$CAP_BODY" "$TEST_TMP_DIR/organiser.jar"
  expect_status 201 "REG-005 created a capacity-1 test conference"
  CAP_ID=$(printf '%s' "$HTTP_BODY" | jq -r '.id // empty')
else
  pass "REG-005 reuse existing capacity-1 test conference (id: $CAP_ID)"
fi

if [ -n "$CAP_ID" ]; then
  # Fill the single seat with attendee one (tolerate an earlier run).
  api POST "/api/conferences/$CAP_ID/register" \
    "{\"conferenceId\":\"$CAP_ID\"}" "$TEST_TMP_DIR/attendee.jar"
  if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "400" ]; then
    pass "REG-005 first attendee holds the single seat (HTTP $HTTP_STATUS)"
  else
    fail "REG-005 first attendee could not take the single seat" "HTTP $HTTP_STATUS — $HTTP_BODY"
  fi

  # Second attendee must be refused because the conference is full.
  login "$TEST_ATTENDEE2_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/attendee2.jar"
  api POST "/api/conferences/$CAP_ID/register" \
    "{\"conferenceId\":\"$CAP_ID\"}" "$TEST_TMP_DIR/attendee2.jar"
  expect_status 400 "REG-005 registration refused when conference is at capacity"
  expect_jq '.error | test("capacity"; "i")' \
    "REG-005 rejection explains the capacity limit"
else
  skip "REG-005 capacity enforcement" "capacity conference could not be resolved"
fi

# REG-006 — an organiser/admin view lists conference registrations
if [ -n "${CAP_ID:-}" ]; then
  api GET "/api/conferences/$CAP_ID/registrations" "" "$TEST_TMP_DIR/organiser.jar"
  expect_status 200 "REG-006 organiser can list conference registrations"
fi

summary
exit $?