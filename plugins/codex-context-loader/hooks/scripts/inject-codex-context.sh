#!/bin/bash
set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

# Exit silently if no settings file
if [ ! -f "$SETTINGS" ]; then
  exit 0
fi

# Exit silently if Codex plugin is not enabled
if ! jq -e '.enabledPlugins["codex@openai-codex"] == true' "$SETTINGS" > /dev/null 2>&1; then
  exit 0
fi

# Codex is installed — read the briefing and inject as systemMessage
CONTEXT_FILE="${CLAUDE_PLUGIN_ROOT}/hooks/context/codex-briefing.md"

if [ ! -f "$CONTEXT_FILE" ]; then
  exit 0
fi

jq -Rs '{ systemMessage: . }' "$CONTEXT_FILE"
