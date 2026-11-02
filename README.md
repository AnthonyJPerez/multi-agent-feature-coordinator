# feature-coordinator

Run one feature across many repositories with coding agents - one
coordinator session, one worker session per repository worktree, contracts
locked by a merged plan, review feedback triaged instead of blindly applied,
and every autonomous decision visible.

It is a plugin in the [obra/superpowers](https://github.com/obra/superpowers)
style: plain-Markdown skills that work in any agent harness, a bootstrap
skill injected at session start, small shell hooks, and one manifest per
ecosystem (Claude Code, GitHub Copilot CLI, Codex, Cursor, Gemini CLI).
The tracker, code host and team chat are configuration: Azure Boards, Jira,
GitHub Issues, Linear or GitLab Issues; GitHub, Azure Repos, GitLab or
Bitbucket; Teams, Slack or Discord.

## How it works

```
<workspace>/                        (not a repository)
  platform-specs/.worktrees/PAY-42/   coordinator  - spec, plan, contracts, docs PRs
  auth-service/.worktrees/PAY-42/     worker       - auth-service PR
  billing-service/.worktrees/PAY-42/  worker       - billing-service PR
  .feature/PAY-42/                    local state  - contract lock, mailbox, briefs, proof
```

1. **Start** - `feature-workspace start PAY-42 --anchor platform-specs --repo auth-service --repo billing-service`
   creates a worktree per repo on the feature branch and the shared state.
2. **Spec PR** - the coordinator writes one spec with you, at maximum
   reasoning effort, and opens it in the anchor repo. You approve and merge.
3. **Plan PR** - the plan holds the PR matrix, per-repo acceptance tests,
   rollout order and the exact contract files (OpenAPI, protobuf, event
   schemas). Code owners approve, you merge, `feature-workspace lock` records
   the contract bytes.
4. **Code wave** - `feature-workspace dispatch` starts one session per repo,
   each in its own worktree with its own instructions, hooks and the ability
   to ask you questions. Each reads the merged plan itself.
5. **Review** - each worker triages its own PR's threads into ripple, small,
   ambiguity, large, disagree or pre-existing; ripples go to the coordinator
   first; three review rounds and it steps back to propose another approach.
6. **Finish** - you merge in plan order with flags off, flip flags in plan
   order, and `feature-workspace finish` cleans up.

You merge, approve, unlock contracts and decide every Tier 3 question.
Nothing goes to a team channel or a cloud service unless you ask.

Why this shape, and what the research behind it found:
[docs/architecture.md](docs/architecture.md).

## What is enforced, and how

| Guarantee | Mechanism | Harnesses |
|---|---|---|
| A session edits only its own worktree | `worktree-guard` PreToolUse hook (file tools and shell commands: redirects, `cp`/`mv`/`rm`, `sed -i`, `git -C`, `cd` into other repos) | Claude Code, Copilot CLI; Codex via `--sandbox workspace-write` |
| Locked contract files do not change | guard hook on edits + `contract-check` in the Stop gate | Claude Code, Copilot CLI (Codex/Cursor/Gemini: the worker runs the check) |
| A worker cannot stop with failing checks | `feature-gate` Stop hook runs contract check + the repo's gate command, blocks once per state | Claude Code, Copilot CLI |
| No force pushes, no pushes to the default branch, no agent merges or approvals | guard hook (`git push --force`, `gh pr merge`, `az repos pr update --status completed`, `glab mr merge`, approvals, auto-complete) | Claude Code, Copilot CLI |
| Contract unlocks and forced cleanup are human-only | guard hook denies `feature-workspace unlock` / `finish --force` | Claude Code, Copilot CLI |
| Tier 3 paths need your OK | `protected_paths` in the team config: Claude Code asks you; others deny with the reason | Claude Code, Copilot CLI |
| Decisions are visible | recording-decisions skill, PR template, decision log; add the CI check in [docs/team-setup.md](docs/team-setup.md) to make it deterministic | all |

The guard is a guardrail against mistakes, not a security boundary; pair it
with your harness's sandbox where you have one.

## Install

The repository is its own marketplace for each ecosystem. If your team
hosts a fork, use its `owner/repo` instead.

**Claude Code**

```text
/plugin marketplace add AnthonyJPerez/multi-agent-feature-coordinator
/plugin install feature-coordinator@feature-coordinator
```

To give a whole team the plugin, commit this to each repo's
`.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "feature-coordinator": { "source": { "source": "github", "repo": "AnthonyJPerez/multi-agent-feature-coordinator" } }
  },
  "enabledPlugins": { "feature-coordinator@feature-coordinator": true }
}
```

**GitHub Copilot CLI** - see [docs/README.copilot.md](docs/README.copilot.md)

```bash
copilot plugin marketplace add AnthonyJPerez/multi-agent-feature-coordinator
copilot plugin install feature-coordinator@feature-coordinator
```

**Codex** - see [docs/README.codex.md](docs/README.codex.md)

```bash
codex plugin marketplace add AnthonyJPerez/multi-agent-feature-coordinator
```

then enable it in `/plugins`, or in `.codex/config.toml`:
`[plugins."feature-coordinator@feature-coordinator"]` with `enabled = true`.

**Cursor** - install from the repository with Cursor's plugin installer; it
reads `.cursor-plugin/plugin.json` (skills plus the session-start hook).

**Gemini CLI**

```bash
gemini extensions install https://github.com/AnthonyJPerez/multi-agent-feature-coordinator
```

Requirements: `git` 2.23+ and `bash` 3.2+ (Git for Windows' bash on
Windows). Optional: `tmux` for `--tmux`; your code host's CLI (`gh`, `az`
with the `azure-devops` extension, `glab`) and tracker CLI (`acli`) or the
matching MCP servers.

## Configure your team's stack

Commit `.feature-coordinator.conf` to the anchor repo:

```ini
tracker = jira                 # azure-boards | jira | github-issues | linear | gitlab-issues | none
tracker.url = https://acme.atlassian.net
code_host = auto               # detected per repo from origin: github | azure-repos | gitlab | bitbucket
chat = teams                   # teams | slack | discord | none
chat.webhook_env = FC_TEAMS_WEBHOOK
branch_prefix = feature/
gate.billing-service = make test lint
protected_paths = **/auth/**, .github/workflows/*, package.json
```

Each engineer can override keys in `<workspace>/.feature/config`. All keys,
examples for common stacks, and code-host approval settings:
[docs/team-setup.md](docs/team-setup.md) and
[the provider references](skills/using-feature-coordinator/references/providers/README.md).

## Use it

In any agent session, describe the feature: "PAY-42 needs changes in
auth-service and billing-service; platform-specs holds our specs." The
coordinating skill takes over from there. Or drive the script directly:

```bash
FW="bash <plugin>/skills/coordinating-multi-repo-features/scripts/feature-workspace"
cd ~/ws
$FW start PAY-42 --anchor platform-specs --repo auth-service --repo billing-service
$FW launch PAY-42 coordinator          # prints the command; --tmux runs it
# ... spec PR merged, plan PR merged ...
$FW lock PAY-42
$FW dispatch PAY-42 --tmux
$FW status PAY-42
$FW finish PAY-42
```

`$FW help` lists every command. Inside a feature worktree, `$FW where` says
which feature, role and files the session belongs to.

## Skills

| Skill | Triggers when |
|---|---|
| using-feature-coordinator | every session (bootstrap) |
| coordinating-multi-repo-features | a change spans repos; you are the coordinator |
| writing-unified-specs | the feature needs its spec |
| locking-contracts-with-a-plan | the plan, contracts or rollout order need writing, amending or locking |
| dispatching-repo-workers | the plan is locked; workers start, relaunch, redirect |
| working-a-repo-slice | the session is a worker in one repo |
| triaging-pr-feedback | review comments arrive |
| recording-decisions | an unrequested choice, or a push |
| verifying-with-proof | about to claim something works |
| briefing-your-human-partner | status or "what happened while I was away" |
| asking-the-team | only when you ask to involve the team |
| finishing-a-multi-repo-feature | approvals or merges are in; rollout; cleanup |

If superpowers is installed too, its engineering skills (brainstorming,
TDD, debugging, verification, code review) keep governing work inside each
repo.

## Development

```bash
bash tests/run-all.sh                 # hooks, workspace script, manifests, skill structure
claude plugin validate . --strict     # if Claude Code is installed
```

See [AGENTS.md](AGENTS.md) for conventions and [docs/porting.md](docs/porting.md)
for adding a harness or a provider.

## License

MIT. Packaging conventions adapted from obra/superpowers (MIT, Copyright (c)
2025 Jesse Vincent); see [NOTICE.md](NOTICE.md).
