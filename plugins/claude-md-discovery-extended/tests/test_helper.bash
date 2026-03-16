#!/usr/bin/env bash
# Shared helpers for bats tests

SCRIPT_DIR="${BATS_TEST_DIRNAME}/../hooks/scripts"
CHECK_SCRIPT="${SCRIPT_DIR}/check-claude-md.sh"
CLEANUP_SCRIPT="${SCRIPT_DIR}/cleanup-session-tracking.sh"

# Build a hook JSON payload. All args are named for clarity.
# Usage: build_json --tool Read --sid session1 --cwd /path --file_path /path/file
#        build_json --tool Glob --sid session1 --cwd /path --path /search/path
build_json() {
  local tool_name="" session_id="" cwd="" file_path="" search_path=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tool)       tool_name="$2"; shift 2 ;;
      --sid)        session_id="$2"; shift 2 ;;
      --cwd)        cwd="$2"; shift 2 ;;
      --file_path)  file_path="$2"; shift 2 ;;
      --path)       search_path="$2"; shift 2 ;;
      *)            shift ;;
    esac
  done

  jq -n \
    --arg tn "${tool_name}" \
    --arg sid "${session_id}" \
    --arg cwd "${cwd}" \
    --arg fp "${file_path}" \
    --arg sp "${search_path}" \
    '{tool_name:$tn, session_id:$sid, cwd:$cwd, tool_input:{file_path:$fp, path:$sp}}'
}

# Run the check script with given JSON, capture exit code and stderr.
# Sets: CHECK_EXIT, CHECK_STDERR
run_check() {
  local json="$1"
  CHECK_STDERR=""
  CHECK_EXIT=0
  CHECK_STDERR=$(echo "${json}" | bash "${CHECK_SCRIPT}" 2>&1 >/dev/null) || CHECK_EXIT=$?
}

# Extract discovered CLAUDE.md paths from stderr output (sorted).
discovered_paths() {
  echo "${CHECK_STDERR}" | grep -oE '/[^ ]+/CLAUDE\.md' | sort || true
}

# Generate a unique session ID per call.
next_sid() {
  echo "bats-${BATS_TEST_NAME}-${RANDOM}-${RANDOM}"
}
