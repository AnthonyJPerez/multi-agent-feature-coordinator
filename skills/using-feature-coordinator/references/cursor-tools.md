# Cursor Tool Notes

Cursor loads this plugin's skills and its session-start hook
(`hooks/hooks-cursor.json`). The worktree guard and the Stop gate are not
wired for Cursor, so:

- Open one Cursor window per feature worktree, never a window on the whole
  workspace folder.
- Before every push, run `fw contract-check <ID>` and the repo's gate
  command yourself.
- Edit only files inside the window's worktree.

| Action the skills name | Cursor |
|---|---|
| Invoke a skill | Skills load by description |
| Ask your human partner | Ask in the chat and wait |
| Dispatch a subagent | Cursor's subagent / background agent support where available; otherwise do the step yourself |
| Track tasks | the todo tool |
| Message another session | The mailbox (`fw mail`) |

Cursor background agents run in the cloud: use them only when your human
partner asks.
