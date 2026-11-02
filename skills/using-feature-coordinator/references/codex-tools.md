# Codex Tool Notes

Codex loads this plugin's skills. Its manifest sets `hooks: {}`, so the
plugin's hooks do **not** run here: no session-start context, no worktree
guard, no Stop gate. Two things replace them:

1. **The sandbox is the guard.** Start every feature session with
   `--sandbox workspace-write` from inside its worktree (the launcher does).
   Writes outside the worktree fail, except the extra writable directories
   the launcher passes: the feature's state folder and this repo's git
   directory (commits write there). Codex can read other worktrees without
   `--add-dir`.
2. **You run the checks yourself.** Before every stop and every push, run
   `fw contract-check <ID>` and the repo's gate command (your brief names
   it), and fix failures before reporting.

Optionally, a team can enable the hooks per repository: see
`docs/README.codex.md` in the plugin.

| Action the skills name | Codex |
|---|---|
| Invoke a skill | Skills load by description; mention one by name to use it |
| Ask your human partner | Ask in your reply and wait for the answer |
| Dispatch a subagent (`Subagent (general-purpose):`) | `spawn_agent` with `fork_turns: "none"` and the filled prompt (needs `[features] multi_agent = true` in your human partner's Codex config) |
| Track tasks | `update_plan` |
| Raise reasoning effort | `/model` and its reasoning effort setting |
| Bounded goal for a worker | State the exit criteria at the start; there is no goal command |
| Poll on a timer | Not available; check when your human partner asks |
| Message another session | The mailbox (`fw mail`) |

## Sessions

- `fw launch <ID> <target> --cli codex` prints `cd <worktree> &&
  FC_SESSION_WORKTREE=... codex --sandbox workspace-write --add-dir <state>
  --add-dir <git dir> '<prompt>'` (the `--add-dir` flags only if your Codex
  version has them).
- Never run feature sessions with `--dangerously-bypass-approvals-and-sandbox`
  or `--sandbox danger-full-access`.
- Hooks are disabled on Windows in Codex; there the sandbox and your own
  checks are all you have.
