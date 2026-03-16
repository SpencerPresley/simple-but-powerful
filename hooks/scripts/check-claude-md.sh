#!/bin/bash
set -Eeuo pipefail

command -v jq &>/dev/null || exit 0
umask 077

input=$(cat)

# Extract all fields in a single jq call to minimize process spawns.
# shellcheck disable=SC2312  # eval captures jq's output, not its return value
eval "$(jq -r '
  @sh "tool_name=\(.tool_name // "")",
  @sh "session_id=\(.session_id // "")",
  @sh "cwd=\(.cwd // "")",
  @sh "file_path=\(.tool_input.file_path // "")",
  @sh "search_path=\(.tool_input.path // "")"
' <<< "${input}")"

if [[ -z "${tool_name}" || -z "${session_id}" || -z "${cwd}" ]]; then
  exit 0
fi

# Select the relevant path based on tool type (file_path/search_path assigned by eval above)
# shellcheck disable=SC2154
case "${tool_name}" in
  Read|Edit|Write) target_path="${file_path}" ;;
  Glob|Grep)       target_path="${search_path}" ;;
  *)               exit 0 ;;
esac

[[ -z "${target_path}" ]] && exit 0

# Get the directory of the target
if [[ -d "${target_path}" ]]; then
  dir="${target_path}"
else
  dir=$(dirname "${target_path}")
fi

# Normalize: remove trailing slashes, guard root becoming empty string
dir="${dir%/}"
cwd="${cwd%/}"
[[ -z "${dir}" ]] && dir="/"
[[ -z "${cwd}" ]] && cwd="/"

# Skip files within the project directory tree.
# Claude Code already handles on-demand CLAUDE.md loading for child directories.
case "${dir}" in
  "${cwd}"|"${cwd}"/*) exit 0 ;;
  *) ;;
esac

# Session-scoped tracking file
tracking_file="${TMPDIR:-/tmp}/claude-md-seen-${session_id}"

# Walk up from the file's directory, collecting unread CLAUDE.md files.
# Stop when we reach a directory that is an ancestor of cwd (loaded at startup).
found=()
current="${dir}"

while [[ "${current}" != "/" ]]; do
  # Stop at directories that are ancestors of cwd — those CLAUDE.md files
  # were already loaded at startup by Claude Code's built-in hierarchy loading.
  case "${cwd}" in
    "${current}"|"${current}"/*) break ;;
    *) ;;
  esac

  if [[ -f "${current}/CLAUDE.md" ]]; then
    if ! { [[ -f "${tracking_file}" ]] && grep -qxF "${current}/CLAUDE.md" "${tracking_file}"; }; then
      found+=("${current}/CLAUDE.md")
      echo "${current}/CLAUDE.md" >> "${tracking_file}"
    fi
  fi

  current=$(dirname "${current}")
done

[[ ${#found[@]} -eq 0 ]] && exit 0

# Output discovery message to stderr (exit 2 feeds stderr to the model)
{
  printf '<claude-md-sibling-discovery>\n'
  printf 'CLAUDE.md file(s) discovered outside your project that you have NOT read this session:\n'
  for f in "${found[@]}"; do
    printf '  - %s\n' "${f}"
  done
  printf '\nYou MUST read these CLAUDE.md files NOW before proceeding '
  printf 'with your current work. Once you have read them, continue working seamlessly — '
  printf 'do not stop to inform the user you read them, just read and continue.\n'
  printf '</claude-md-sibling-discovery>\n'
} >&2
exit 2
