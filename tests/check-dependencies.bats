#!/usr/bin/env bats

load test_helper

DEPS_SCRIPT="${SCRIPT_DIR}/check-dependencies.sh"

# To simulate jq missing, we create a wrapper script that overrides PATH
# before sourcing the real script. We can't just set PATH="/dev/null" because
# bash itself needs to resolve builtins and the script uses 'command -v'.
setup() {
  TEST_DIR=$(mktemp -d)

  # Create a wrapper that puts an empty dir first in PATH,
  # hiding jq but keeping bash builtins functional.
  EMPTY_BIN="${TEST_DIR}/empty-bin"
  mkdir -p "${EMPTY_BIN}"

  cat > "${TEST_DIR}/no-jq-wrapper.sh" <<WRAPPER
#!/bin/bash
export PATH="${EMPTY_BIN}"
source "${DEPS_SCRIPT}"
WRAPPER
  chmod +x "${TEST_DIR}/no-jq-wrapper.sh"
}

teardown() {
  rm -rf "${TEST_DIR}"
}

@test "exits 0 when jq is available" {
  local exit_code=0
  bash "${DEPS_SCRIPT}" 2>/dev/null || exit_code=$?
  [[ "${exit_code}" -eq 0 ]]
}

@test "exits 2 when jq is not available" {
  local exit_code=0
  bash "${TEST_DIR}/no-jq-wrapper.sh" 2>/dev/null || exit_code=$?
  [[ "${exit_code}" -eq 2 ]]
}

@test "stderr contains install instructions when jq missing" {
  local stderr_out=""
  stderr_out=$(bash "${TEST_DIR}/no-jq-wrapper.sh" 2>&1 >/dev/null) || true
  [[ "${stderr_out}" == *"requires jq"* ]]
  [[ "${stderr_out}" == *"brew install jq"* ]]
}

@test "no stderr output when jq is available" {
  local stderr_out=""
  stderr_out=$(bash "${DEPS_SCRIPT}" 2>&1 >/dev/null) || true
  [[ -z "${stderr_out}" ]]
}
