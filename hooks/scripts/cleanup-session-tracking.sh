#!/bin/bash
# Remove this session's CLAUDE.md tracking file on exit.
set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')

[ -z "$session_id" ] && exit 0

rm -f "${TMPDIR:-/tmp}/claude-md-seen-${session_id}"
