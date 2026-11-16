#!/usr/bin/env bash
# Runs every Convene API test in dependency order.
#
# Order matters: later suites reuse records created by earlier ones.
#   auth -> conference -> attendee registration -> session -> speaker
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck source=helpers.sh
source ./helpers.sh

OVERALL=0

run() {
  local script="$1"
  printf '\n%s========== %s ==========%s\n' "$C_BOLD" "$script" "$C_RESET"
  if [ ! -f "$script" ]; then
    printf 'missing test script: %s\n' "$script" >&2
    OVERALL=1
    return
  fi
  bash "$script"
  local rc=$?
  if [ $rc -ne 0 ]; then
    OVERALL=1
  fi
}

run ./auth_test.sh
run ./conference_test.sh
run ./attendee_registration_test.sh
run ./session_test.sh
run ./speaker_test.sh

printf '\n%s############################%s\n' "$C_BOLD" "$C_RESET"
if [ $OVERALL -eq 0 ]; then
  printf '%sALL TEST SUITES COMPLETED WITHOUT FAILURES%s\n' "$C_GREEN" "$C_RESET"
else
  printf '%sONE OR MORE TEST SUITES REPORTED FAILURES%s\n' "$C_RED" "$C_RESET"
fi
printf '%s############################%s\n' "$C_BOLD" "$C_RESET"

exit $OVERALL