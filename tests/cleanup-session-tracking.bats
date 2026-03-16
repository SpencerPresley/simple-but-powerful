#!/usr/bin/env bats

load test_helper

setup() {
  command -v jq &>/dev/null || skip "jq is not installed"
}

teardown() {
  rm -f "${TMPDIR:-/tmp}"/claude-md-seen-bats-* 2>/dev/null || true
}

@test "removes tracking file for given session_id" {
  local sid="bats-cleanup-test-1"
  local tracking_file="${TMPDIR:-/tmp}/claude-md-seen-${sid}"

  echo "test data" > "${tracking_file}"
  [[ -f "${tracking_file}" ]]

  echo "{\"session_id\":\"${sid}\"}" | bash "${CLEANUP_SCRIPT}"

  [[ ! -f "${tracking_file}" ]]
}

@test "exits 0 when tracking file does not exist" {
  local sid="bats-cleanup-nonexistent"
  local exit_code=0
  echo "{\"session_id\":\"${sid}\"}" | bash "${CLEANUP_SCRIPT}" || exit_code=$?
  [[ "${exit_code}" -eq 0 ]]
}

@test "exits 0 when session_id is missing" {
  local exit_code=0
  echo '{}' | bash "${CLEANUP_SCRIPT}" || exit_code=$?
  [[ "${exit_code}" -eq 0 ]]
}

@test "exits 0 on empty input" {
  local exit_code=0
  echo '{}' | bash "${CLEANUP_SCRIPT}" || exit_code=$?
  [[ "${exit_code}" -eq 0 ]]
}
