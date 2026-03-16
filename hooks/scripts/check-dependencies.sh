#!/bin/bash
# Warn once at session start if jq is not installed.
set -Eeuo pipefail

if command -v jq &>/dev/null; then
  exit 0
fi

{
  printf '<claude-md-sibling-discovery>\n'
  printf 'The claude-md-sibling-discovery plugin requires jq but it is not installed.\n'
  printf 'The plugin will not function until jq is available.\n'
  printf 'Install: brew install jq (macOS) or apt-get install jq (Linux)\n'
  printf '</claude-md-sibling-discovery>\n'
} >&2
exit 2
