# GitHub Copilot CLI Tool Notes

Copilot CLI loads this plugin from its Claude-format manifest and
`hooks/hooks.json`: the session-start context, the worktree guard and the
Stop gate run here too. Hook timeouts default to 30 seconds in Copilot; a
gate command slower than that is cut off and the stop goes through, so keep
Copilot gates fast and leave the slow suites to CI.

| Action the skills name | Copilot CLI |
|---|---|
| Invoke a skill | Skills load by description; `/skills` lists them |
| Ask your human partner | `ask_user` (never start workers with `--no-ask-user`) |
| Dispatch a subagent (`Subagent (general-purpose):`) | A custom agent or the built-in task agent with the filled prompt; custom agents need `include-custom-instructions: true` to follow repo instructions |
| Second opinion | `/rubber-duck` |
| Track tasks | the todo tool |
| Work read-only until approved | Plan mode (Shift+Tab) |
| Raise reasoning effort | `/model` - a stronger model or a higher Fusion tier |
| Bounded goal for a worker | Autopilot with `--max-autopilot-continues <n>` and `--max-ai-credits <n>` |
| Poll on a timer (only when asked) | `/every 15m <prompt>` (experimental; only while the session is open) |
| Read other worktrees | `--add-dir` (the launcher adds them) |
| Message another session | No verified cross-session messaging: the mailbox (`fw mail`) is the channel |

## Sessions

- `fw launch <ID> <target> --cli copilot` prints `cd <worktree> &&
  FC_SESSION_WORKTREE=... copilot --add-dir ...` with the first prompt (via
  `-i` when your Copilot version has it, otherwise as a comment to paste).
- One `copilot` session per worktree. Do not use `/fleet` as the code wave:
  its subagents share the launching session's directory and hooks.
- Hooks load from the current working directory, which is another reason to
  start each session inside its worktree.

## Never

- `/pr fix feedback` and `/pr auto` - they apply every comment and loop to
  merge. Use triaging-pr-feedback.
- `/delegate` and other cloud agents unless your human partner asks.

## Settings worth setting

- Session sync, Copilot Memory and Dreaming upload session content; your
  human partner's organization may want them off for this work (org policy).
- For long-lived feature branches, prefer merge over rebase for conflict
  resolution in `.github/copilot/settings.json` if your Copilot version
  offers that setting.
