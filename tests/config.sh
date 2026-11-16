#!/usr/bin/env bash
# Shared configuration for the Convene API tests.
# Override any value by exporting it before running a test, e.g.
#   BASE_URL="http://localhost:3000" ./tests/auth_test.sh

# Deployed Cloudflare Worker (production).
# For local development against the Express server, use http://localhost:3000
export BASE_URL="${BASE_URL:-https://convene_backend.conference-management-system-backend.workers.dev}"

# Seeded development accounts. These are fictional test credentials.
export ADMIN_EMAIL="${ADMIN_EMAIL:-samuel@convene.com}"
export ADMIN_PASSWORD="${ADMIN_PASSWORD:-Convene@2026}"

export ORGANISER_EMAIL="${ORGANISER_EMAIL:-austin@convene.com}"
export ORGANISER_PASSWORD="${ORGANISER_PASSWORD:-Convene@2026}"

# Clearly identifiable fictional test data. Scripts reuse these where possible
# so repeated runs do not pile up duplicate records.
export TEST_ATTENDEE_EMAIL="${TEST_ATTENDEE_EMAIL:-test.attendee@convene.com}"
export TEST_ATTENDEE2_EMAIL="${TEST_ATTENDEE2_EMAIL:-test.attendee2@convene.com}"
export TEST_ATTENDEE_PASSWORD="${TEST_ATTENDEE_PASSWORD:-TestPass123!}"
export TEST_SPEAKER_EMAIL="${TEST_SPEAKER_EMAIL:-test.speaker@convene.com}"

export TEST_CONFERENCE_TITLE="${TEST_CONFERENCE_TITLE:-API Test Conference}"
export TEST_CAPACITY_CONFERENCE_TITLE="${TEST_CAPACITY_CONFERENCE_TITLE:-API Test Capacity Conference}"
export TEST_SESSION_TITLE="${TEST_SESSION_TITLE:-API Test Session}"

# Where cookie jars and captured responses are written for this run.
export TEST_TMP_DIR="${TEST_TMP_DIR:-$(mktemp -d)}"