# feature-coordinator for Codex

Codex installs this plugin from `.codex-plugin/plugin.json` (skills) through
the marketplace in `.agents/plugins/marketplace.json`. The manifest sets
`"hooks": {}`, so the plugin's hooks do not run in Codex - the same choice
superpowers makes, and plugins with hooks are not eligible for the public
plugin directory.

## Install

```bash
codex plugin marketplace add AnthonyJPerez/multi-agent-feature-coordinator
```

Then enable it with `/plugins`, or for everyone working in a repo, in that
repo's `.codex/config.toml`:

```toml
[plugins."feature-coordinator@feature-coordinator"]
enabled = true
```

Subagent dispatch in the skills (fresh-context reviewer, summarizer) needs
multi-agent support in your own Codex config (`~/.codex/config.toml`):

```toml
[features]
multi_agent = true
```

## Sessions and isolation

```bash
fw launch PAY-42 coordinator --cli codex
fw dispatch PAY-42 --cli codex --tmux
```

Each session starts inside its worktree with `--sandbox workspace-write`.
The sandbox is what keeps a Codex session in its worktree: writes elsewhere
fail. The launcher adds only two writable directories: the feature's state
folder (mailbox, logs, proof) and the repo's git directory (a worktree's
commits are written there). Codex can read the other worktrees without
`--add-dir`.

Without hooks, workers run `fw contract-check <ID>` and the gate command
themselves before every stop and push (the skills and `codex-tools.md`
say so).

## Optional: run the hooks in Codex

Codex supports hooks behind a feature flag. A team that wants the guard and
gate in Codex can add, per repository, a `.codex/hooks.json` pointing at an
installed copy of this plugin, and enable `codex_hooks`:

```toml
# ~/.codex/config.toml (each engineer)
[features]
codex_hooks = true
```

```json
{
  "hooks": {
    "PreToolUse": [
      { "hooks": [ { "type": "command", "command": "bash \"$FC_PLUGIN_DIR/hooks/worktree-guard\"" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": "bash \"$FC_PLUGIN_DIR/hooks/feature-gate\"", "timeout": 900 } ] }
    ]
  }
}
```

`FC_PLUGIN_DIR` is wherever each engineer has the plugin checked out. Codex
hook payloads differ from Claude Code's in places (for example how
`apply_patch` input is passed); the guard reads the common fields and scans
patch text for `*** Update File:` lines, but pilot it before relying on it.
Codex hooks are disabled on Windows.
