# Working on feature-coordinator

Instructions for agents (and people) changing this repository.

## Layout

- `skills/<name>/SKILL.md` - one skill per folder, plus its templates and
  references. `using-feature-coordinator` is the bootstrap injected at
  session start.
- `skills/coordinating-multi-repo-features/scripts/` - `feature-workspace`
  (the CLI) and `fc-lib` (shared by the CLI and the hooks).
- `hooks/` - extensionless bash hook scripts, `run-hook.cmd` (polyglot
  dispatcher), `hooks.json` (Claude Code and Copilot CLI),
  `hooks-cursor.json`.
- Manifests: `.claude-plugin/`, `.codex-plugin/`, `.agents/plugins/`,
  `.cursor-plugin/`, `gemini-extension.json` + `GEMINI.md`.
- `tests/` - one folder per area; `tests/run-all.sh` runs everything.

## Skill conventions

- Frontmatter has `name` and `description` only. The description starts with
  "Use when", lists triggers only and never summarizes the workflow - agents
  follow a workflow summary instead of reading the skill.
- Skills name actions, not tools: "ask your human partner", "dispatch a
  subagent", "open a draft PR (provider reference H1)". Harness tool names go
  in `references/<harness>-tools.md`; provider commands go in
  `references/providers/<provider>.md`.
- Say "your human partner", not "the user".
- Keep every `SKILL.md` under 20,000 bytes; move detail to a reference file.
- Subagent prompts are templates inside the skill, dispatched as
  `Subagent (general-purpose):`. No `agents/` or `commands/` folders.
- The bootstrap skill is injected into every session, including unrelated
  single-repo work: keep it short and make clear when the skills do not
  apply.

## Script conventions

- Bash 3.2 compatible (macOS default): no associative arrays, `mapfile`,
  `${var,,}`, negative indexes; expand possibly-empty arrays with
  `${a[@]+"${a[@]}"}`.
- No runtime dependencies beyond `git` and POSIX tools. `jq` is allowed in
  development scripts only.
- Invoke scripts with `bash <path>`; packagers may strip executable bits.
  The one exception is `hooks/run-hook.cmd`: harnesses execute it directly,
  so it must stay executable (git mode 100755). A live test in Claude Code
  fails with "Permission denied" (status 126) when the bit is lost.
- Hooks never fail the session: unexpected errors exit 0. Only the guard's
  deliberate deny exits 2. Print with `printf`, not heredocs (bash 5.3 hang).
- Hooks never read or write the user's global configuration.
- Values that come from configuration are validated in `fc_conf_validate`.
- Keep `${var//pattern/replacement}` replacements literal:
  `fc-lib` disables bash 5.2's `patsub_replacement`.
- Never put literal single quotes inside a double-quoted string inside
  `$(...)` that is itself inside double quotes: bash 3.2 mis-parses it. Quote
  with parameter expansion and variables instead (see `q()` and
  `json_values`).
- Parse JSON with `fc_json_load` (awk), not `[[ =~ ]]`: macOS's regex engine
  is pathologically slow on large payloads and differs on edge cases.
- In tests, put a JSON payload with escaped quotes in a variable and pass
  the variable: bash 3.2 mangles `\"` inside `"$(...)"`, most visibly
  for arrays. A mangled payload makes the guard fail open, so a test that
  expects exit 0 can pass for the wrong reason.

## Before you commit

```bash
bash tests/run-all.sh
claude plugin validate . --strict   # when Claude Code is installed
bash scripts/bump-version.sh --check
```

Add tests with every behavior change, especially new guard rules (both the
deny case and a nearby allow case).
