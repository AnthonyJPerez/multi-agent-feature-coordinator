# feature-coordinator for GitHub Copilot CLI

Copilot CLI reads this repository's Claude-format manifest
(`.claude-plugin/plugin.json`) and `hooks/hooks.json`, so it gets the same
skills, session-start context, worktree guard and Stop gate as Claude Code.

## Install

```bash
copilot plugin marketplace add AnthonyJPerez/multi-agent-feature-coordinator
copilot plugin install feature-coordinator@feature-coordinator
```

or straight from the repository: `copilot plugin install AnthonyJPerez/multi-agent-feature-coordinator`.
`/skills` inside a session should list the twelve skills.

## Sessions

```bash
fw launch PAY-42 coordinator --cli copilot
fw dispatch PAY-42 --cli copilot --tmux
```

or set `default_cli = copilot` in the team config (or `FC_DEFAULT_CLI=copilot`
for yourself). Each command starts `copilot` inside its worktree with the
other worktrees added (`--add-dir`) and `FC_SESSION_WORKTREE` set, so the
hooks know which session they are in.

Models: choose with `/model` (or pass `--extra "--model <name>"` to the
launcher); the `*_model` keys in the team config apply to Claude Code only.

## Hooks in Copilot

| Hook | Copilot behavior |
|---|---|
| session-start | Emits `{"additionalContext": ...}` (detected via `COPILOT_CLI=1`) |
| worktree-guard | Exit 2 denies the tool call. Accepts both the Claude-compatible payload (`tool_name`, `tool_input`) and Copilot's native one (`toolName`, `toolArgs`) |
| feature-gate | Blocks the stop with `{"decision": "block", "reason": ...}` |

- Copilot's default hook timeout is 30 seconds and a timeout lets the action
  through. Keep gate commands under that, or rely on CI for slow suites.
- `protected_paths` edits are denied (Copilot has no "ask" decision for
  hooks in Autopilot); the agent asks you instead.
- Pilot check: run a session in a feature worktree, ask it to write a file
  in a sibling worktree, and confirm the guard denies it. If your Copilot
  version names tools differently and the matcher misses them, remove the
  `matcher` line from `hooks/hooks.json` in your fork - the guard filters
  tools itself.

## Copilot features to avoid for feature work

- `/pr fix feedback` and `/pr auto` (apply everything, loop to merge).
- `/fleet` as the code wave (shares one directory and one set of hooks).
- `/delegate` and cloud agents, unless you choose to use them.
- `--no-ask-user` for workers - they need to ask you Tier 3 questions.

Bounded autonomy: Autopilot with `--max-autopilot-continues` and
`--max-ai-credits` caps.
