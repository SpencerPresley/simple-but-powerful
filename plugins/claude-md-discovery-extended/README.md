# claude-md-discovery-extended

A Claude Code plugin that fills a gap in `CLAUDE.md` auto-discovery. Claude Code has built-in discovery for some directory relationships but not all. This plugin covers what Claude Code doesn't: sibling directories, cousin directories, or completely unrelated trees. Discovery happens on demand when the model accesses files in those directories.

```text
grandparent/
  parent/
    projectA/  ← your project
    projectB/  ← sibling
  tools/
    linter/    ← cousin
other-team/
  services/
    api/       ← unrelated tree
```

## Background

Claude Code loads `CLAUDE.md` files from three sources:

1. **Ancestor directories**: at launch, Claude Code walks up from the working directory and loads every `CLAUDE.md` it finds.
2. **Child directories**: when the model reads a file in a subdirectory, Claude Code loads any `CLAUDE.md` along that subdirectory's path.
3. **Explicit directories**: passing `--add-dir` at launch with `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` loads `CLAUDE.md` files from specified directories at startup.

See the [CLAUDE.md docs](https://code.claude.com/docs/en/memory) for full details.

None of these cover directories outside the ancestor/child path discovered mid-session. Given:

```text
grandparent/
  parent/
    projectA/       <- your project (cwd)
      CLAUDE.md
      src/
    projectB/       <- sibling
      CLAUDE.md
      src/
  tools/
    linter/         <- cousin
      CLAUDE.md
other-team/
  services/
    api/            <- unrelated tree
      CLAUDE.md
```

If you launch in `projectA`, Claude Code loads `projectA/CLAUDE.md`, `parent/CLAUDE.md`, and `grandparent/CLAUDE.md` (ancestors). But if the model then reads a file in `projectB/src/`, `tools/linter/`, or `other-team/services/api/`, none of those `CLAUDE.md` files are loaded.

`--add-dir` can solve this, but it loads everything at startup. You need to know which directories matter ahead of time, specify them every session, and their `CLAUDE.md` contents occupy the context window from the start whether they end up being relevant or not. This plugin takes a [progressive disclosure](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) approach instead: `CLAUDE.md` files are discovered and loaded on demand as the model accesses files in those directories, keeping the context window lean until the instructions are actually needed.

## How It Works

Three [hooks](https://code.claude.com/docs/en/hooks):

- **PostToolUse** (matcher: `Read|Glob|Grep|Edit|Write|Bash`): checks if the accessed path is outside the project tree. If so, walks up the directory tree looking for undiscovered `CLAUDE.md` files and tells the model to read them. For the Bash tool, paths are extracted from the command string using `shlex` tokenization.
- **SessionStart**: checks that `jq` and `python3` are installed, warns if missing.
- **SessionEnd**: deletes the session-scoped tracking file.

Files within the project tree are skipped with a single string comparison. The directory walk stops at ancestor directories (already loaded at launch).

Each discovery is recorded in a session-scoped tracking file (`/tmp/claude-md-seen-{session_id}`). Once a `CLAUDE.md` has been discovered and reported, it won't trigger again for the rest of the session. The SessionEnd hook cleans up this file automatically.

## Requirements

- [**jq**](https://jqlang.github.io/jq/): used by the session cleanup hook. If missing, the plugin warns at session start.
- **Python 3.10+**: runs the main discovery hook. Typically pre-installed on macOS and most Linux distributions.

## Limitations

- **Bash path extraction is best-effort**: paths are extracted from Bash commands via `shlex` tokenization. This handles common patterns (`cat /path/to/file`, `ls /some/dir`, quoted paths) but won't catch paths in redirects, pipes, or subshells.
- **Only matches `CLAUDE.md`**: does not look for `.claude.md` (lowercase with dot prefix).

## License

MIT
