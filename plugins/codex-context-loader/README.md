# codex-context-loader

Dynamically injects detailed Codex plugin context into Claude Code sessions — but only when the Codex plugin is actually installed.

## Why this exists

The Codex plugin (`codex@openai-codex`) ships with several skills and an agent, but most of them are internal plumbing with terse, unhelpful descriptions. When installed, they consume context tokens in every session regardless of whether you're using Codex. That's pure bloat when you don't need it.

This plugin solves two problems:

1. **Context bloat**: You might not always want the Codex plugin active, but when you do, you want Claude to actually understand what's available. This hook only fires when the Codex plugin is detected in `installed_plugins.json`, so you pay zero tokens when it's not installed.

2. **Lacking descriptions**: The agent-facing Codex skill descriptions are minimal — things like "Internal helper contract for calling the codex-companion runtime from Claude Code" don't tell the model enough to use the tools effectively. The injected context provides a fleshed-out briefing covering when to use the rescue agent, what flags are available, and how the internal pieces fit together.

## How it works

A `SessionStart` hook runs a bash script that:

1. Checks `~/.claude/plugins/installed_plugins.json` for the `codex@openai-codex` key
2. If found, reads `hooks/context/codex-briefing.md` and outputs it as a `systemMessage`
3. If not found, exits silently with no output and no token cost

The briefing content lives in a separate markdown file (`hooks/context/codex-briefing.md`) so it's easy to edit without touching the script.

## Editing the briefing

To change what context gets injected, edit `hooks/context/codex-briefing.md`. No script changes needed. The content is read at session start and JSON-encoded automatically.
