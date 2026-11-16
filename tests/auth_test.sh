#!/usr/bin/env bash
# AUTH-xxx — authentication and role-based access control.
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=config.sh
source ./config.sh
# shellcheck source=helpers.sh
source ./helpers.sh

require_cmd curl
require_cmd jq

section "Authentication and access control"

# AUTH-001 — admin login with valid credentials
login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$TEST_TMP_DIR/admin.jar"
expect_status 200 "AUTH-001 admin login with valid credentials"
expect_jq '.success == true' "AUTH-001 admin login reports success"
expect_jq '.data.role == "admin"' "AUTH-001 admin receives the admin role"

# AUTH-002 — organiser login with valid credentials
login "$ORGANISER_EMAIL" "$ORGANISER_PASSWORD" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "AUTH-002 organiser login with valid credentials"
expect_jq '.data.role == "organiser"' "AUTH-002 organiser receives the organiser role"

# AUTH-003 — invalid password is rejected
login "$ADMIN_EMAIL" "definitely-not-the-password" "$TEST_TMP_DIR/bad.jar"
expect_status 401 "AUTH-003 invalid password is rejected"

# AUTH-004 — unknown email is rejected
login "nobody@convene.com" "whatever" "$TEST_TMP_DIR/unknown.jar"
expect_status 401 "AUTH-004 unknown email is rejected"

# AUTH-005 — protected endpoint rejects unauthenticated requests
api GET /api/auth/me
expect_status 401 "AUTH-005 /api/auth/me rejects unauthenticated request"

api GET /api/conferences
expect_status 401 "AUTH-005 protected conference list rejects unauthenticated request"

# AUTH-006 — valid session can read /api/auth/me
api GET /api/auth/me "" "$TEST_TMP_DIR/admin.jar"
expect_status 200 "AUTH-006 authenticated /api/auth/me succeeds"
expect_jq '.data.email == "'"$ADMIN_EMAIL"'"' "AUTH-006 /api/auth/me returns the admin identity"

# AUTH-007 — role-based access: organiser may list members
api GET /api/auth/members "" "$TEST_TMP_DIR/organiser.jar"
expect_status 200 "AUTH-007 organiser can list members"

# AUTH-008 — role-based access: member management is admin/organiser only
# A speaker/attendee account is created here only to prove the restriction.
SIGNUP_BODY='{"name":"Test Speaker","email":"'"$TEST_SPEAKER_EMAIL"'","password":"'"$TEST_ATTENDEE_PASSWORD"'","role":"speaker"}'
api POST /api/auth/signup "$SIGNUP_BODY"
if [ "$HTTP_STATUS" = "201" ]; then
  pass "AUTH-008 created a temporary speaker account for the role check"
elif [ "$HTTP_STATUS" = "409" ]; then
  pass "AUTH-008 temporary speaker account already existed"
else
  fail "AUTH-008 could not create a temporary speaker account" "HTTP $HTTP_STATUS — $HTTP_BODY"
fi

login "$TEST_SPEAKER_EMAIL" "$TEST_ATTENDEE_PASSWORD" "$TEST_TMP_DIR/speaker.jar"
api GET /api/auth/members "" "$TEST_TMP_DIR/speaker.jar"
expect_status 403 "AUTH-008 speaker is forbidden from member management"

# AUTH-009 — logout clears the session
login "$ADMIN_EMAIL" "$ADMIN_PASSWORD" "$TEST_TMP_DIR/logout.jar"
api POST /api/auth/logout "" "$TEST_TMP_DIR/logout.jar"
expect_status 200 "AUTH-009 logout succeeds"
api GET /api/auth/me "" "$TEST_TMP_DIR/logout.jar"
expect_status 401 "AUTH-009 session is rejected after logout"

summary
exit $?