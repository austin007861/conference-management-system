# Convene — API Test Guide

This is the single reference for testing the Convene backend. Everything here is
executed from the terminal with `curl`; there is no testing framework, no UI test,
and no screenshot evidence.

---

## A. Testing overview

**What API testing means.** We send real HTTP requests to the running backend and
inspect the status code and JSON body that come back. No browser is involved.

**Why cURL.** `curl` is already installed on macOS and Linux, needs no setup, and
shows the exact request and response. That makes it easy to demonstrate a test
live during the presentation.

**What is being tested.** The deployed Cloudflare Worker:

```
https://convene_backend.conference-management-system-backend.workers.dev
```

To point the tests at a local Express server instead:

```bash
BASE_URL="http://localhost:3000" ./tests/run_all.sh
```

**How the scripts work.** Each `*_test.sh` file:

1. Logs in with `curl` and saves the session cookie to a cookie jar.
2. Sends further requests reusing that cookie jar.
3. Compares the real HTTP status and JSON body against the expected value.
4. Prints `[PASS]`, `[FAIL]` or `[SKIP]` for every assertion.

**Important.** These tests write to the deployed D1 database. They only create
clearly labelled test records (`API Test Conference`, `API Test Session`,
`test.attendee@convene.com`, …) and never delete or reset existing data.

---

## B. Requirements

| Tool | Check | Notes |
|------|-------|-------|
| Bash | `bash --version` | macOS and Linux include it |
| cURL | `curl --version` | Used for every request |
| jq | `jq --version` | Used to inspect JSON responses |

Install `jq` if it is missing:

```bash
# macOS
brew install jq

# Debian / Ubuntu
sudo apt-get install jq
```

---

## C. Test configuration

All configuration lives in [`config.sh`](./config.sh). Every value can be
overridden by exporting it before running a test.

| Variable | Default | Purpose |
|----------|---------|---------|
| `BASE_URL` | deployed Worker URL | Backend under test |
| `ADMIN_EMAIL` | `samuel@convene.com` | Administrator account |
| `ADMIN_PASSWORD` | `Convene@2026` | Administrator password |
| `ORGANISER_EMAIL` | `austin@convene.com` | Organiser account |
| `ORGANISER_PASSWORD` | `Convene@2026` | Organiser password |
| `TEST_ATTENDEE_EMAIL` | `test.attendee@convene.com` | Fictional attendee |
| `TEST_ATTENDEE2_EMAIL` | `test.attendee2@convene.com` | Second fictional attendee (capacity tests) |
| `TEST_ATTENDEE_PASSWORD` | `TestPass123!` | Fictional attendee password |
| `TEST_SPEAKER_EMAIL` | `test.speaker@convene.com` | Fictional speaker |
| `TEST_CONFERENCE_TITLE` | `API Test Conference` | Reused conference record |
| `TEST_CAPACITY_CONFERENCE_TITLE` | `API Test Capacity Conference` | Capacity-1 conference |
| `TEST_SESSION_TITLE` | `API Test Session` | Reused session record |

**Authentication.** The API uses an `HttpOnly` session cookie (`session_id`), not a
bearer token. `helpers.sh` logs in with `curl -c` to write the cookie to a jar, then
reuses it with `curl -b`. Because the frontend is on `pages.dev` and the backend on
`workers.dev`, the cookie is issued as `SameSite=None; Secure`, and the tests send an
`Origin` header so CORS behaves as it does in the browser.

**Test data is fictional.** No real names, emails or passwords are used.

---

## D. How to run the tests

From the repository root:

```bash
# Make the scripts executable (once only)
chmod +x tests/*.sh

# Run everything in dependency order
./tests/run_all.sh
```

Run a single suite:

```bash
./tests/auth_test.sh
./tests/conference_test.sh
./tests/attendee_registration_test.sh
./tests/session_test.sh
./tests/speaker_test.sh
```

**Run order matters.** Later suites reuse records created by earlier ones, so
`run_all.sh` runs them in this order:

```
auth → conference → attendee registration → session → speaker
```

If you run one suite on its own and it reports `[SKIP]`, run the suite it depends on
first. The skip message names the missing prerequisite.

---

## E. Every test explained

### `auth_test.sh` — authentication and access control

| ID | Test | What the script sends | Expected result |
|----|------|----------------------|-----------------|
| AUTH-001 | Admin login | `POST /api/auth/login` with the admin email and password | HTTP 200, `success: true`, `data.role == "admin"` |
| AUTH-002 | Organiser login | `POST /api/auth/login` with the organiser credentials | HTTP 200, `data.role == "organiser"` |
| AUTH-003 | Invalid password | `POST /api/auth/login` with a wrong password | HTTP 401 |
| AUTH-004 | Unknown email | `POST /api/auth/login` with an unused address | HTTP 401 |
| AUTH-005 | Unauthenticated access | `GET /api/auth/me` and `GET /api/conferences` with no cookie | HTTP 401 |
| AUTH-006 | Valid session identity | `GET /api/auth/me` with the admin cookie | HTTP 200 and the admin email |
| AUTH-007 | Organiser may list members | `GET /api/auth/members` with the organiser cookie | HTTP 200 |
| AUTH-008 | Speaker forbidden from member management | `GET /api/auth/members` with a speaker cookie | HTTP 403 |
| AUTH-009 | Logout invalidates the session | `POST /api/auth/logout`, then `GET /api/auth/me` | HTTP 200, then HTTP 401 |

Example command:

```bash
./tests/auth_test.sh
```

Example output:

```
[PASS] AUTH-001 admin login with valid credentials (HTTP 200)
[PASS] AUTH-003 invalid password is rejected (HTTP 401)
[PASS] AUTH-005 /api/auth/me rejects unauthenticated request (HTTP 401)
[PASS] AUTH-008 speaker is forbidden from member management (HTTP 403)
```

### `conference_test.sh` — conference management

| ID | Test | What the script sends | Expected result |
|----|------|----------------------|-----------------|
| CONF-001 | List conferences | `GET /api/conferences` as organiser | HTTP 200 and a JSON array |
| CONF-002 | Create or reuse a conference | `POST /api/conferences` with `title`, `description`, `startDate`, `endDate`, `capacity`, `status` | HTTP 201, `startDate` present. If a conference with the test title already exists, it is reused instead of duplicated |
| CONF-003 | Retrieve by id | `GET /api/conferences/:id` | HTTP 200 with `speakers`, `sessions`, `venues`, `documents` arrays |
| CONF-004 | Update conference | `PATCH /api/conferences/:id` with a new `description` | HTTP 200 and the new description; re-fetching confirms it persisted |
| CONF-005 | Unauthorised create | `POST /api/conferences` with a speaker cookie | HTTP 403 |
| CONF-006 | Available list | `GET /api/conferences/available` | HTTP 200, test conference present with `registrationOpen: true` |

Example command:

```bash
./tests/conference_test.sh
```

### `attendee_registration_test.sh` — registration and capacity

| ID | Test | What the script sends | Expected result |
|----|------|----------------------|-----------------|
| REG-001 | Create test attendee | `POST /api/auth/signup` with role `attendee` | HTTP 201, or HTTP 409 if the account already exists (reused) |
| REG-001 | Signup rejects admin role | `POST /api/auth/signup` with role `admin` | HTTP 400 |
| REG-002 | Attendee login | `POST /api/auth/login` as the test attendee | HTTP 200, `role == "attendee"` |
| REG-003 | Attendee registers | `POST /api/conferences/:id/register` | HTTP 201, or HTTP 400 if already registered from an earlier run |
| REG-004 | Duplicate registration | Repeat the same `POST .../register` | HTTP 400 and an "already registered" message |
| REG-005 | Capacity enforcement | Register a second attendee for a conference with `capacity: 1` | HTTP 400 and a message containing "capacity" |
| REG-006 | Organiser lists registrations | `GET /api/conferences/:id/registrations` | HTTP 200 |

Example commands:

```bash
./tests/attendee_registration_test.sh
```

### `session_test.sh` — session management and capacity

| ID | Test | What the script sends | Expected result |
|----|------|----------------------|-----------------|
| SESS-001 | List sessions | `GET /api/sessions` | HTTP 200 and a JSON array |
| SESS-002 | Create or reuse a session | `POST /api/sessions` with `conferenceId`, `title`, `startTime`, `endTime`, `capacity: 1` | HTTP 201 and `capacity == 1` |
| SESS-003 | Filter by conference | `GET /api/sessions?conferenceId=...` | HTTP 200 and the test session present |
| SESS-004 | Available sessions | `GET /api/sessions/available` | HTTP 200 and `capacity == 1` |
| SESS-005 | First attendee takes the seat | `POST /api/sessions/:id/register` | HTTP 201, or HTTP 400 if already registered |
| SESS-006 | Capacity enforcement | Second attendee registers for the same session | HTTP 400 and a message containing "capacity" |
| SESS-007 | Organiser lists session registrations | `GET /api/sessions/:id/registrations` | HTTP 200 |

Example command:

```bash
./tests/session_test.sh
```

### `speaker_test.sh` — speaker records and assignment

| ID | Test | What the script sends | Expected result |
|----|------|----------------------|-----------------|
| SPK-001 | List speakers | `GET /api/speakers` | HTTP 200 and a JSON array |
| SPK-002 | Create or reuse a speaker | `POST /api/speakers` with a `bio` | HTTP 201; reused if the bio already exists |
| SPK-003 | Unauthorised speaker create | `POST /api/speakers` with an attendee cookie | HTTP 403 |
| SPK-004 | Assign speaker to session | `POST /api/session-speakers` with `sessionId`, `speakerId`, `speakerRole` | HTTP 201, or HTTP 409 if already assigned |
| SPK-005 | Conference detail lists speaker | `GET /api/conferences/:id` | HTTP 200 and the speaker present in `speakers` |

Example command:

```bash
./tests/speaker_test.sh
```

---

## F. Expected results summary

| Test ID | Test | Expected result |
|---------|------|-----------------|
| AUTH-001 | Admin login | Login succeeds, admin role returned |
| AUTH-002 | Organiser login | Login succeeds, organiser role returned |
| AUTH-003 | Invalid login | Request rejected with 401 |
| AUTH-004 | Unknown email | Request rejected with 401 |
| AUTH-005 | Unauthenticated access | Access denied with 401 |
| AUTH-006 | Session identity | Correct identity returned |
| AUTH-007 | Organiser member access | Members listed |
| AUTH-008 | Speaker member access | Forbidden with 403 |
| AUTH-009 | Logout | Session invalidated |
| CONF-001 | Retrieve conferences | Conference list returned |
| CONF-002 | Create conference | Conference saved with 201 |
| CONF-003 | Retrieve one conference | Detail returned with related arrays |
| CONF-004 | Update conference | Change persisted |
| CONF-005 | Unauthorised create | Forbidden with 403 |
| CONF-006 | Available conferences | Test conference listed as open |
| REG-001 | Attendee signup | Account created, admin role refused |
| REG-002 | Attendee login | Login succeeds |
| REG-003 | Conference registration | Registration succeeds |
| REG-004 | Duplicate registration | Duplicate rejected with 400 |
| REG-005 | Conference capacity | Registration refused at capacity |
| REG-006 | Registration listing | Organiser sees registrations |
| SESS-001 | Retrieve sessions | Session list returned |
| SESS-002 | Create session | Session saved with 201 |
| SESS-003 | Session filter | Filtered list returned |
| SESS-004 | Available sessions | Session listed with capacity |
| SESS-005 | Session registration | Registration succeeds |
| SESS-006 | Session capacity | Registration refused at capacity |
| SESS-007 | Session registration listing | Organiser sees registrations |
| SPK-001 | Retrieve speakers | Speaker list returned |
| SPK-002 | Create speaker | Speaker saved with 201 |
| SPK-003 | Unauthorised speaker create | Forbidden with 403 |
| SPK-004 | Speaker assignment | Assignment created, duplicate refused with 409 |
| SPK-005 | Assigned speaker visible | Speaker appears in conference detail |

**These are expected results, not measured results.** A test is only reported as
passed once the script has actually run it.

---

## G. Understanding the output

**`[PASS]`** — the request returned the expected status and body. The assertion ran
and matched.

**`[FAIL]`** — the request returned something else. The line below prints the
expected value, the actual status, and the response body so you can see why.

**`[SKIP]`** — the test could not run because a prerequisite record was missing.
This is not a pass and not a failure; run the prerequisite suite first.

**HTTP status meanings used by this API:**

| Status | Meaning |
|--------|---------|
| 200 | Success |
| 201 | Resource created |
| 204 | Success with no body (delete/cancel) |
| 400 | Validation or business-rule rejection (duplicate, capacity, closed registration) |
| 401 | Not authenticated, or wrong credentials |
| 403 | Authenticated but not permitted for this role |
| 404 | Resource not found |
| 409 | Conflict (duplicate speaker assignment) |
| 500 | Unexpected server error — treat as a backend defect |

**Troubleshooting:**

- Every request returns `000` — the backend URL is unreachable; check `BASE_URL`.
- All auth tests fail with `401` — the seed accounts may have been removed, or
  `ADMIN_PASSWORD` / `ORGANISER_PASSWORD` no longer match.
- A test returns `500` — capture the response body; it is the backend's error.
- A test reports `[SKIP]` — run `./tests/conference_test.sh` first, since later
  suites depend on the conference it creates.

---

## H. Presenting the results

Run the whole suite and show the terminal:

```bash
./tests/run_all.sh
```

The final line of each suite gives the totals, for example:

```
============================
16 passed | 0 failed | 0 skipped
============================
```

For a deeper demonstration, show a single request and its raw response:

```bash
# Log in and keep the cookie
curl -c /tmp/jar -s -X POST \
  -H 'Content-Type: application/json' \
  -d '{"email":"samuel@convene.com","password":"Convene@2026"}' \
  "$BASE_URL/api/auth/login" | jq

# Prove the session is rejected once removed
curl -b /tmp/jar -s -o /dev/null -w '%{http_code}\n' "$BASE_URL/api/auth/me"
```

Three tests that are worth presenting:

1. **AUTH-003 + AUTH-001** — a wrong password is rejected with 401, then the correct
   password succeeds. Demonstrates authentication and error handling.
2. **CONF-005** — a speaker is forbidden from creating a conference with 403.
   Demonstrates role-based access control.
3. **REG-005 / SESS-006** — a conference or session at capacity refuses the next
   registration with 400. Demonstrates business-rule enforcement.

**Do not claim a test passed until you have run it.** If a suite fails, say so and
show the failure output — that is stronger evidence than a claim.

---

## I. Notes and limitations

- The tests run against the **deployed** Worker, so they create records in the live
  D1 database. They are written to be re-runnable: existing test records are reused
  rather than duplicated, and nothing is deleted.
- Public signup only allows `attendee` and `speaker`. Admin and organiser accounts
  are seeded, not created by the API.
- The R2 storage seam (`Backend/src/storage/r2.ts`) exists but no document-upload
  route is wired to it, so document upload is not covered by these tests.
- Reports and dashboard endpoints are read-only and are not asserted here; they are
  covered indirectly through the list endpoints.

---

## J. Files in this folder

| File | Purpose |
|------|---------|
| `config.sh` | Backend URL, credentials, test data names |
| `helpers.sh` | `api`, `expect_status`, `expect_jq`, `pass`, `fail`, `skip`, `summary` |
| `auth_test.sh` | AUTH-001 … AUTH-009 |
| `conference_test.sh` | CONF-001 … CONF-006 |
| `attendee_registration_test.sh` | REG-001 … REG-006 |
| `session_test.sh` | SESS-001 … SESS-007 |
| `speaker_test.sh` | SPK-001 … SPK-005 |
| `run_all.sh` | Runs every suite in dependency order |
| `TESTS.md` | This guide |