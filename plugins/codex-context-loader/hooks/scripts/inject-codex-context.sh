#!/bin/bash
set -euo pipefail

INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

# Exit silently if no installed plugins file
if [ ! -f "$INSTALLED_PLUGINS" ]; then
  exit 0
fi

# Exit silently if Codex plugin is not installed
if ! grep -q '"codex@openai-codex"' "$INSTALLED_PLUGINS"; then
  exit 0
fi

# Codex is installed — read the briefing and inject as systemMessage
CONTEXT_FILE="${CLAUDE_PLUGIN_ROOT}/hooks/context/codex-briefing.md"

if [ ! -f "$CONTEXT_FILE" ]; then
  exit 0
fi

jq -Rs '{ systemMessage: . }' "$CONTEXT_FILE"
