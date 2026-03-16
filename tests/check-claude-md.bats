#!/usr/bin/env bats

load test_helper

setup() {
  command -v jq &>/dev/null || skip "jq is not installed"

  # Layout: workspace/project (cwd), workspace/sibling/deep/nested,
  #         with CLAUDE.md at sibling/, workspace/, and sibling/deep/nested/
  TEST_ROOT=$(mktemp -d)
  PROJECT="${TEST_ROOT}/workspace/project"
  SIBLING="${TEST_ROOT}/workspace/sibling"
  SIBLING_DEEP="${TEST_ROOT}/workspace/sibling/deep/nested"
  PARENT="${TEST_ROOT}/workspace"

  mkdir -p "${PROJECT}/subdir"
  mkdir -p "${SIBLING_DEEP}"

  echo "# sibling" > "${SIBLING}/CLAUDE.md"
  echo "# parent"  > "${PARENT}/CLAUDE.md"
  echo "# deep"    > "${SIBLING_DEEP}/CLAUDE.md"
}

teardown() {
  rm -rf "${TEST_ROOT}"
  rm -f "${TMPDIR:-/tmp}"/claude-md-seen-bats-* 2>/dev/null || true
}

@test "exits 0 on empty JSON" {
  run_check '{}'
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "exits 0 when tool_name is missing" {
  run_check '{"session_id":"x","cwd":"/tmp","tool_input":{}}'
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "exits 0 when session_id is missing" {
  run_check '{"tool_name":"Read","cwd":"/tmp","tool_input":{}}'
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "exits 0 when cwd is missing" {
  run_check '{"tool_name":"Read","session_id":"x","tool_input":{}}'
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "exits 0 for unknown tool type" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Bash --sid "${sid}" --cwd "${PROJECT}")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "exits 0 when file_path is empty" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "exits 0 when path is empty for Glob" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Glob --sid "${sid}" --cwd "${PROJECT}" --path "")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

# Claude Code already loads CLAUDE.md from child directories on demand,
# so the hook must not re-report files under cwd.

@test "skips file in project root" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${PROJECT}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "skips file in project subdirectory" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${PROJECT}/subdir/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

# The upward walk stops at any directory that is an ancestor of cwd, because
# Claude Code loads CLAUDE.md files from the cwd-to-root chain at startup.
# Reporting them again would be redundant.

@test "stops walk at ancestor of cwd" {
  # cwd is deep inside sibling; reading a file in sibling's parent
  # should stop at sibling (ancestor of cwd) and not report its CLAUDE.md
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${SIBLING_DEEP}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "discovers sibling CLAUDE.md" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
  local paths; paths=$(discovered_paths)
  [[ "${paths}" == *"${SIBLING}/CLAUDE.md"* ]]
}

@test "discovers parent CLAUDE.md alongside sibling" {
  # When reading in sibling dir, should find sibling/CLAUDE.md.
  # Parent (workspace/CLAUDE.md) is an ancestor of cwd (workspace/project),
  # so it should NOT be reported (already loaded at startup).
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  local paths; paths=$(discovered_paths)
  [[ "${paths}" == *"${SIBLING}/CLAUDE.md"* ]]
  # Parent is ancestor of cwd, should be excluded
  [[ "${paths}" != *"${PARENT}/CLAUDE.md"* ]]
}

@test "discovers multiple CLAUDE.md files walking up from deep sibling" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING_DEEP}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
  local paths; paths=$(discovered_paths)
  [[ "${paths}" == *"${SIBLING_DEEP}/CLAUDE.md"* ]]
  [[ "${paths}" == *"${SIBLING}/CLAUDE.md"* ]]
}

@test "no discovery when sibling has no CLAUDE.md" {
  rm "${SIBLING}/CLAUDE.md"
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  # Only parent/CLAUDE.md remains, but its directory is an ancestor of cwd, so it's excluded too
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "Read extracts file_path" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
}

@test "Edit extracts file_path" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Edit --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
}

@test "Write extracts file_path" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Write --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
}

@test "Glob extracts path" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Glob --sid "${sid}" --cwd "${PROJECT}" --path "${SIBLING}")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
}

@test "Grep extracts path" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Grep --sid "${sid}" --cwd "${PROJECT}" --path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
}

@test "handles target_path that is a directory" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Glob --sid "${sid}" --cwd "${PROJECT}" --path "${SIBLING}")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
  local paths; paths=$(discovered_paths)
  [[ "${paths}" == *"${SIBLING}/CLAUDE.md"* ]]
}

@test "second call with same session_id does not re-report" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")

  # First call — should discover
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 2 ]]

  # Second call — same session, should be deduped
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 ]]
}

@test "different session_id reports independently" {
  local sid1; sid1=$(next_sid)
  local sid2; sid2=$(next_sid)
  local json1; json1=$(build_json --tool Read --sid "${sid1}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  local json2; json2=$(build_json --tool Read --sid "${sid2}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")

  run_check "${json1}"
  [[ "${CHECK_EXIT}" -eq 2 ]]

  run_check "${json2}"
  [[ "${CHECK_EXIT}" -eq 2 ]]
}

@test "stderr contains xml-style tags" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_STDERR}" == *"<claude-md-sibling-discovery>"* ]]
  [[ "${CHECK_STDERR}" == *"</claude-md-sibling-discovery>"* ]]
}

@test "stderr lists discovered file paths" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_STDERR}" == *"${SIBLING}/CLAUDE.md"* ]]
}

@test "handles root path without error" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "${PROJECT}" --file_path "/somefile.txt")
  run_check "${json}"
  # Accept either exit code: 0 (no CLAUDE.md at /) or 2 (system has /CLAUDE.md)
  [[ "${CHECK_EXIT}" -eq 0 || "${CHECK_EXIT}" -eq 2 ]]
}

@test "handles cwd at root without error" {
  local sid; sid=$(next_sid)
  local json; json=$(build_json --tool Read --sid "${sid}" --cwd "/" --file_path "${SIBLING}/file.txt")
  run_check "${json}"
  [[ "${CHECK_EXIT}" -eq 0 || "${CHECK_EXIT}" -eq 2 ]]
}
