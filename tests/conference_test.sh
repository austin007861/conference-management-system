#!/usr/bin/env bash
# CONF-xxx — conference management and authorisation.
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=config.sh
source ./config.sh
# shellcheck source=helpers.sh
source ./helpers.sh

require_cmd curl
require_cmd jq

# Future dates, portable across GNU and BSD date.
if date -u -d "+30 days" +%Y >/dev/null 2>&1; then
  START=$(date -u -d "+30 days" +%Y-%m-%dT09:00:00.000Z)
  END=$(date -u -d "+32 days" +%Y-%m-%dT17:00:00.000Z)
else
  START=$(date -u -v+30d +%Y-%m-%dT09:00:00.000Z)
  END=$(date -u -v+32d +%Y-%m-%dT17:00:00.000Z)
fi

section "Conference management"

# Ensure an authenticated organiser session.
login "$ORGANISER_EMAIL" "$ORGANISER_PASSWORD" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "CONF-000 organiser session established"

# CONF-001 — list conferences
api GET /api/conferences "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "CONF-001 list conferences as organiser"
expect_json "CONF-001 conference list is JSON"
if printf '%s' "$HTTP_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
  pass "CONF-001 conference list is an array"
else
  fail "CONF-001 conference list is an array" "got: $HTTP_BODY"
fi

# CONF-002 — create (or reuse) the API test conference
api GET /api/conferences "" "$TEST_TMP_DIR/organiser.jar"
EXISTING_ID=$(printf '%s' "$HTTP_BODY" | jq -r --arg t "$TEST_CONFERENCE_TITLE" \
  '[.[] | select(.title == $t)][0].id // empty')

if [ -n "$EXISTING_ID" ]; then
  pass "CONF-002 reuse existing test conference (id: $EXISTING_ID)"
  CONF_ID="$EXISTING_ID"
else
  CONF_BODY=$(jq -nc --arg t "$TEST_CONFERENCE_TITLE" --arg s "$START" --arg e "$END" \
    '{title:$t, description:"Created by the Convene API test suite.", startDate:$s, endDate:$e, capacity:100, status:"upcoming"}')
  api POST /api/conferences "$CONF_BODY" "$TEST_TMP_DIR/organiser.jar"
  expect_status 201 "CONF-002 create conference as organiser"
  expect_jq '.title == "'"$TEST_CONFERENCE_TITLE"'"' "CONF-002 created conference has the expected title"
  expect_jq '.startDate != null' "CONF-002 created conference has a startDate"
  CONF_ID=$(printf '%s' "$HTTP_BODY" | jq -r '.id // empty')
fi

if [ -z "$CONF_ID" ]; then
  fail "CONF-002 no conference id available — later conference tests cannot run"
  summary
  exit 1
fi
export CONF_ID

# CONF-003 — retrieve the conference by id
api GET "/api/conferences/$CONF_ID" "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "CONF-003 retrieve conference by id"
expect_jq '.id == "'"$CONF_ID"'"' "CONF-003 retrieved conference matches the requested id"
expect_jq '.speakers | type == "array"' "CONF-003 conference detail includes a speakers array"
expect_jq '.sessions | type == "array"' "CONF-003 conference detail includes a sessions array"

# CONF-004 — update conference details
UPDATED_DESCRIPTION="Updated by API test at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
api PATCH "/api/conferences/$CONF_ID" \
  "{\"description\":\"$UPDATED_DESCRIPTION\"}" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "CONF-004 update conference as organiser"
expect_jq '.description == "'"$UPDATED_DESCRIPTION"'"' "CONF-004 update is reflected in the response"

api GET "/api/conferences/$CONF_ID" "" "$TEST_TMP_DIR/organiser.jar"
expect_jq '.description == "'"$UPDATED_DESCRIPTION"'"' "CONF-004 update persisted after re-fetch"

# CONF-005 — attendee role cannot create conferences
api POST /api/auth/signup \
  "{\"name\":\"Test Speaker\",\"email\":\"$TEST_SPEAKER_EMAIL\",\"password\":\"$TEST_ATTENDEE_PASSWORD\",\"role\":\"speaker\"}"
if [ "$HTTP_STATUS" = "201" ] || [ "$HTTP_STATUS" = "409" ]; then
  pass "CONF-005 temporary speaker account available for the authorisation check"
else
  fail "CONF-005 could not prepare a speaker account" "HTTP $HTTP_STATUS — $HTTP_BODY"
fi

login "$TEST_SPEAKER_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/speaker.jar"
NEW_CONF=$(jq -nc --arg t "Unauthorised Conference" --arg s "$START" --arg e "$END" \
  '{title:$t, description:"Should be rejected", startDate:$s, endDate:$e}')
api POST /api/conferences "$NEW_CONF" "$TEST_TMP_DIR/speaker.jar"
expect_status 403 "CONF-005 speaker is forbidden from creating a conference"

# CONF-006 — available list reports registration state
api GET /api/conferences/available "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "CONF-006 list available conferences"
expect_jq '[.[] | select(.conferenceId == "'"$CONF_ID"'")] | length > 0' \
  "CONF-006 test conference appears in the available list"
expect_jq '[.[] | select(.conferenceId == "'"$CONF_ID"'")][0].registrationOpen == true' \
  "CONF-006 test conference has registration open (upcoming status)"

summary
exit $?