# Codex Integration (OpenAI GPT-5.4)

The Codex plugin provides access to OpenAI's Codex/GPT-5.4 as a second AI collaborator you can delegate work to.

## codex:codex-rescue (Agent)

Delegates tasks to Codex through a companion runtime. Use it proactively when:

- Stuck on a bug and want a fresh perspective from a different model
- Want a second implementation or diagnosis pass
- Need deeper root-cause investigation with independent analysis

The agent is a thin forwarding wrapper — it shapes the prompt, hands it to Codex, and returns the result unchanged. It does not inspect the repo or solve problems itself.

User flags: `--background` (async), `--wait` (block), `--resume` (continue prior work), `--fresh` (start clean), `--model <name>` (e.g. `spark` for gpt-5.3-codex-spark), `--effort <level>` (none/minimal/low/medium/high/xhigh). Defaults to write-capable.

## codex:rescue (Skill)

User-invocable trigger for the rescue agent. Invoke via `/codex:rescue`.

## codex:setup (Skill)

Verifies Codex CLI installation and optionally enables the stop-time review gate (runs a Codex review before allowing session end).

## Internal Skills

These are used internally by the rescue agent. Do not invoke directly.

- **codex-cli-runtime**: Runtime contract for calling codex-companion. The rescue agent's only tool.
- **codex-result-handling**: How to present Codex output. Key rule: after review findings, always ask the user which issues to fix — never auto-apply.
- **gpt-5-4-prompting**: Prompt engineering for GPT-5.4. XML-tagged block structure: task, output contract, verification loop, grounding rules.
