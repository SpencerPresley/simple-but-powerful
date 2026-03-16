#!/bin/bash
set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

if [ -z "$tool_name" ] || [ -z "$session_id" ] || [ -z "$cwd" ]; then
  exit 0
fi

# Extract the relevant path based on tool type
case "$tool_name" in
  Read)  target_path=$(echo "$input" | jq -r '.tool_input.file_path // empty') ;;
  Glob)  target_path=$(echo "$input" | jq -r '.tool_input.path // empty') ;;
  Grep)  target_path=$(echo "$input" | jq -r '.tool_input.path // empty') ;;
  Edit)  target_path=$(echo "$input" | jq -r '.tool_input.file_path // empty') ;;
  Write) target_path=$(echo "$input" | jq -r '.tool_input.file_path // empty') ;;
  *)     exit 0 ;;
esac

[ -z "$target_path" ] && exit 0

# Get the directory of the target
if [ -d "$target_path" ]; then
  dir="$target_path"
else
  dir=$(dirname "$target_path")
fi

# Normalize: remove trailing slashes
dir="${dir%/}"
cwd="${cwd%/}"

# Skip files within the project directory tree.
# Claude Code already handles on-demand CLAUDE.md loading for child directories.
case "$dir" in
  "$cwd"|"$cwd"/*) exit 0 ;;
esac

# Session-scoped tracking file
tracking_file="${TMPDIR:-/tmp}/claude-md-seen-${session_id}"

# Walk up from the file's directory, collecting unread CLAUDE.md files.
# Stop when we reach a directory that is an ancestor of cwd (loaded at startup).
found=()
current="$dir"

while [ "$current" != "/" ]; do
  # Stop at directories that are ancestors of cwd — those CLAUDE.md files
  # were already loaded at startup by Claude Code's built-in hierarchy loading.
  case "$cwd" in
    "$current"|"$current"/*) break ;;
  esac

  if [ -f "$current/CLAUDE.md" ]; then
    if ! { [ -f "$tracking_file" ] && grep -qxF "$current/CLAUDE.md" "$tracking_file"; }; then
      found+=("$current/CLAUDE.md")
      echo "$current/CLAUDE.md" >> "$tracking_file"
    fi
  fi

  current=$(dirname "$current")
done

[ ${#found[@]} -eq 0 ] && exit 0

# Output discovery message to stderr (exit 2 feeds stderr to the model)
{
  printf '<claude-md-sibling-discovery>\n'
  printf 'CLAUDE.md file(s) discovered outside your project that you have NOT read this session:\n'
  for f in "${found[@]}"; do
    printf '  - %s\n' "$f"
  done
  printf '\nYou MUST read these CLAUDE.md files NOW before proceeding '
  printf 'with your current work. Once you have read them, continue working seamlessly — '
  printf 'do not stop to inform the user you read them, just read and continue.\n'
  printf '</claude-md-sibling-discovery>\n'
} >&2
exit 2
