# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@../AGENTS.md

This file lives in `.claude/` because the repository root is also the plugin
root: `claude plugin validate . --strict`, which the manifest tests run,
rejects a `CLAUDE.md` there. Keep conventions that every agent shares in
`AGENTS.md`; this file adds what is specific to Claude Code.

## What this repository is

The feature-coordinator plugin itself. There is no build step: the product is
markdown skills, bash hooks and a bash CLI, shipped from one tree to Claude
Code, Copilot CLI, Codex, Cursor and Gemini CLI. `README.md` describes what it
does for its users; `docs/architecture.md` records why it is built this way
(requirements R1-R30, the harness parity table, the harness facts the design
depends on).

## Commands

```bash
bash tests/run-all.sh                       # every suite; prints [FAIL] lines and per-suite totals
VERBOSE=1 bash tests/run-all.sh             # stream every assertion (what CI runs)
bash tests/hooks/test-worktree-guard.sh     # one suite: run any tests/<area>/test-*.sh directly
claude plugin validate . --strict
bash scripts/bump-version.sh --check        # all manifest versions agree (needs jq)
bash scripts/bump-version.sh 0.2.0          # set the version in every file listed in .version-bump.json
python3 docs/images/how-it-works.py         # regenerate the README diagram SVGs
```

- Every suite sources `tests/lib.sh`, which builds bare remotes and clones
  under a temp dir with its own `HOME` and `GIT_CONFIG_GLOBAL`. Build new
  tests from its helpers (`make_workspace`, `commit_and_push`,
  `merge_to_main`, `fake_cli`, the `assert_*` family).
- Development needs `python3`, `jq` and `shellcheck` besides `git` and
  `bash` (Windows: `winget install jqlang.jq koalaman.shellcheck`). A
  missing optional tool passes as "skipped": no `shellcheck` skips the lint
  check, no `python3` skips the JSON and brace-expansion checks, and the
  `claude plugin validate` check runs only when `claude` is on PATH. CI
  installs shellcheck on Linux, so a warning can fail CI while local runs
  pass.
- CI runs Linux (bash 5, gawk) and macOS (`/bin/bash` 3.2, BSD awk), not
  Windows, and is the reference. Under Git for Windows some assertions fail
  for reasons outside the code under test:
  - `python3` prints CRLF (manifests: "SessionStart/PreToolUse script exists");
  - NTFS has no executable bit ("run-hook.cmd is executable"; the git mode
    is still 100755);
  - the Windows command-line length limit ("content mentioning file_path",
    "large here-document");
  - slow process start-up ("same state does not rerun the gate").

  The two "Windows project dir" tests, which fake `cygpath`, also fail on
  real Windows; their cause is not diagnosed yet.
- Suites are listed by hand: a new suite goes into the loop in
  `tests/run-all.sh`, and a new runtime script into the `scripts` array in
  `tests/shell-lint/test-shell-lint.sh` (the first five entries are the set
  checked for bash 4+ features).
- `tests/skills/test-skill-structure.sh` asserts exactly twelve skills and
  that the bootstrap skill names every other skill; adding a skill means
  updating both.
- Behavior changes get an entry under `## Unreleased` in `RELEASE-NOTES.md`.

## Architecture

**One library, three runtime entry points.**
`skills/coordinating-multi-repo-features/scripts/fc-lib` is sourced (never
run) by the CLI and by all three hooks: paths, worktree records, config
resolution and validation, the awk JSON parser, code-host detection,
provider-reference lookup.

- `feature-workspace` is the CLI (`cmd_*` functions). It creates one
  worktree per repository at `<repo>/.worktrees/<ID>/` and a state folder at
  `<workspace>/.feature/<ID>/`, outside every repository. The full layout,
  branch names, `repos.tsv` columns, lock format and config precedence are
  in `skills/coordinating-multi-repo-features/references/workspace-and-state.md`.
- `hooks/session-start` injects `skills/using-feature-coordinator/SKILL.md`
  into every session, plus a feature-context block inside a feature
  worktree. It emits exactly one JSON field, picked by environment variable
  (`CURSOR_PLUGIN_ROOT`; `CLAUDE_PLUGIN_ROOT` without `COPILOT_CLI`; else
  the Copilot shape).
- `hooks/worktree-guard` (PreToolUse) tokenizes shell commands itself and
  has one `analyze_*` function per tool family (git push, `gh`, `az`,
  `glab`, `tea`, Gerrit ssh, REST calls, the CLI's own `unlock` and
  `finish --force`). It accepts both Claude Code and Copilot payload shapes.
- `hooks/feature-gate` (Stop) runs `contract-check` plus the repo's gate
  command in worker worktrees. It blocks once per worktree fingerprint
  (`gates/<repo>.*`), so a second stop on the same state passes.

**How a hook knows which session it serves.** `start` writes a record per
worktree at `<git-common-dir>/feature-coordinator/<worktree>.env`, and
`fc_feature_context` reads it. The identity directory is
`FC_SESSION_WORKTREE` (exported by `launch`/`dispatch`), then
`CLAUDE_PROJECT_DIR`, then the payload's cwd, then `$PWD`, never where the
agent's shell has since `cd`'d. Outside a `/.worktrees/` path with a record,
every hook does nothing, including in sessions working on this repository.
`FC_GUARD=off`, `FC_GATE=off` and `FC_GUARD_DEBUG=1` control them per
session.

**Hook dispatch and packaging.** Every `hooks/hooks.json` entry runs
`hooks/run-hook.cmd <name>`. That file is a polyglot: cmd.exe runs its batch
block, which finds Git for Windows' bash; Unix shells skip that block as a
heredoc. The PreToolUse matcher lists Claude Code and Copilot CLI tool names
together. Codex's manifest sets `"hooks": {}` and relies on its sandbox;
Cursor wires only session-start (`hooks/hooks-cursor.json`); Gemini gets the
bootstrap through `GEMINI.md` includes. The version appears in five
manifests, and `tests/manifests/test-manifests.sh` fails on any drift, so
change it only with `bump-version.sh`.

**Skills stay harness- and provider-agnostic.** Skills name actions and
action codes (T1-T5 tracker, H1-H9 code host, C1-C2 chat). The concrete
commands live in
`skills/using-feature-coordinator/references/providers/<provider>.md`, and
harness tool names in `references/<harness>-tools.md`. `fc_provider_ref`
maps a configured value to its reference file, and the code host is resolved
per repository (`code_host.<repo>`, else `fc_detect_host` on `origin`).
Adding a harness or provider touches the CLI, the library, the guard, the
references and the tests together. `docs/porting.md` lists every file.

**Line endings.** `.gitattributes` forces LF on `*.sh`, `*.cmd`, the
extensionless hooks and the two scripts. With `core.autocrlf=true` on Windows,
every other file checks out as CRLF. A new extensionless bash script needs an
`eol=lf` line there, or bash fails on the `\r`.
