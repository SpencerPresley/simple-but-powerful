#!/bin/bash
# Remove this session's CLAUDE.md tracking file on exit.
set -Eeuo pipefail

command -v jq &>/dev/null || exit 0

input=$(cat)
session_id=$(jq -r '.session_id // empty' <<< "${input}")

[[ -z "${session_id}" ]] && exit 0

rm -f "${TMPDIR:-/tmp}/claude-md-seen-${session_id}"
