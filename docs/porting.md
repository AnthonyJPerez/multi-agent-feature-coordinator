# Porting: a New Harness or a New Provider

## A new agent harness

Follow superpowers' porting guide (`docs/porting-to-a-new-harness.md` in
obra/superpowers); this plugin uses the same three shapes.

1. **Manifest** - add the harness's plugin or extension manifest pointing at
   `./skills/`. Add its version field to `.version-bump.json`.
2. **Bootstrap** - get `skills/using-feature-coordinator/SKILL.md` in front
   of the model at session start:
   - shell hook harnesses: add a branch to `hooks/session-start` for the
     harness's environment variable and JSON field (emit exactly one field);
   - instructions-file harnesses: `@`-include the skill and the tool mapping,
     like `GEMINI.md`.
3. **Tool mapping** - write `skills/using-feature-coordinator/references/<harness>-tools.md`
   mapping the actions the skills name (ask your human partner, dispatch a
   subagent, track tasks, bounded goal, poll, message another session) and
   saying which hooks run. Link it from the bootstrap's Platform Adaptation
   list.
4. **Hooks** - if the harness can block tool calls and stops, wire
   `worktree-guard` (exit 2 = deny) and `feature-gate`
   (`{"decision":"block"}`). If its payload differs, teach the guard the
   field names in its dispatch section and add test payloads.
5. **Launcher** - add a branch to `launch_command` in `feature-workspace`
   for the CLI: start in the worktree, export `FC_SESSION_WORKTREE`, add
   read access to the other worktrees and write access to the state folder
   without widening write access to sibling repos.
6. **Tests** - payload tests for the new shapes in `tests/hooks/`, and a
   manifest check in `tests/manifests/`.

## A new tracker, code host or chat

1. Add the value to `fc_conf_validate` and a reference file name to
   `fc_provider_ref` in `fc-lib`.
2. Code hosts: add detection to `fc_detect_host`, a parser for the origin
   URL if the CLI needs one, and branches in `pr_summary` / `pr_merged` in
   `feature-workspace`. Add the host's merge, approve and auto-merge
   commands to the guard (`analyze_*` in `hooks/worktree-guard`).
3. Write `skills/using-feature-coordinator/references/providers/<name>.md`
   implementing the action codes it supports (T1-T5, H1-H9, C1-C2), saying
   plainly which it cannot do, and keeping secrets in environment
   variables.
4. Add it to the tables in `references/providers/README.md`.
5. Tests: config validation, host detection from sample URLs, guard denials
   for its merge/approve commands.
