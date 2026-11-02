# Claude Code Tool Notes

Claude Code is the reference harness. The plugin's hooks run here in full:
session-start context, the worktree guard (PreToolUse) and the Stop gate.

| Action the skills name | Claude Code |
|---|---|
| Invoke a skill | `Skill` tool, `feature-coordinator:<skill-name>` |
| Ask your human partner | Ask in the conversation, or `AskUserQuestion` for multiple choice (main session only - subagents cannot ask) |
| Dispatch a subagent (`Subagent (general-purpose):`) | `Agent` tool with the filled prompt; the built-in `Explore` agent for read-only research |
| Small fast model for a summarizer | `model: haiku` on the dispatch |
| Track tasks | the todo / task list tools |
| Work read-only until approved | Plan mode (`--permission-mode plan` or Shift+Tab) |
| Raise reasoning effort | `/effort max` (or `--effort` at launch); the launcher passes `effort` from the team config |
| Bounded goal for a worker | `/goal "<exit criteria>"` |
| Poll on a timer (only when asked) | `/loop 15m <prompt>` - runs only while the session is open and idle, expires after 7 days |
| Read other worktrees | Launched with `--add-dir` for each; `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` loads their CLAUDE.md and rules (v2.1.257+). Their hooks and settings do not load - that is why each repo gets its own session |
| Message another session | Cross-session messaging (`SendMessage`, research preview) only to nudge; the mailbox (`fw mail`) is the record |

## Sessions

- `fw launch` / `fw dispatch` print `cd <worktree> && FC_SESSION_WORKTREE=...
  claude --model ... --effort ... --add-dir ... '<prompt>'`. With `--tmux`
  each session gets a tmux window.
- Background sessions (`claude --bg`, agent view) are a research preview;
  if your human partner uses them, start them from the worktree and check
  they stay in that worktree rather than moving to a `.claude/worktrees/`
  one.
- Do not use agent teams, `isolation: worktree` subagents or `/batch` as
  repo workers: they run in the launching session's repository.
- An advisor model (`advisorModel` setting) is optional and experimental;
  Claude decides when to call it.

## Recommended repo settings

In each repo's committed `.claude/settings.json`, so everyone gets the plugin:

```json
{
  "extraKnownMarketplaces": {
    "feature-coordinator": { "source": { "source": "github", "repo": "<org>/feature-coordinator" } }
  },
  "enabledPlugins": { "feature-coordinator@feature-coordinator": true },
  "permissions": { "deny": ["Bash(git push --force*)", "Bash(git push -f*)"] }
}
```

Organization-wide enforcement (managed settings): force-enable the plugin,
`permissions.disableBypassPermissionsMode: "disable"`, and
`allowManagedHooksOnly: true` (hooks from force-enabled plugins still run).

## Things that are opt-in only

Cloud code review, `/code-review ultra`, cloud sessions, routines and
`/schedule` (they run in the cloud), remote projects. Use them only when your
human partner turns them on for this feature.
