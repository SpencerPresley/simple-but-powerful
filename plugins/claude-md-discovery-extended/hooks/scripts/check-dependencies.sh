#!/bin/bash
# Warn once at session start if required dependencies are not installed.
set -Eeuo pipefail

missing=()

if ! command -v jq &>/dev/null; then
  missing+=("jq")
fi

if ! command -v python3 &>/dev/null; then
  missing+=("python3")
fi

[[ ${#missing[@]} -eq 0 ]] && exit 0

{
  printf '<claude-md-discovery-extended>\n'
  printf 'The claude-md-discovery-extended plugin requires the following but they are not installed:\n'
  for dep in "${missing[@]}"; do
    printf '  - %s\n' "${dep}"
  done
  printf 'The plugin will not function until these are available.\n'
  printf 'Install: brew install jq (macOS) or apt-get install jq (Linux)\n'
  printf 'Python 3 is typically pre-installed on macOS and most Linux distributions.\n'
  printf '</claude-md-discovery-extended>\n'
} >&2
exit 2
