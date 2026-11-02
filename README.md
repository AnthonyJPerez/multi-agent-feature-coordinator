# feature-coordinator

[![tests](https://github.com/AnthonyJPerez/multi-agent-feature-coordinator/actions/workflows/test.yml/badge.svg)](https://github.com/AnthonyJPerez/multi-agent-feature-coordinator/actions/workflows/test.yml)

**Build one feature across many repositories with a team of coding agents.**
One agent works in each repository, all of them in parallel on your machine,
all building against the same locked contracts, while you approve each phase
and merge every pull request.

It runs in Claude Code, GitHub Copilot CLI, Codex, Cursor and Gemini CLI. It
works with repositories on GitHub, Azure DevOps, GitLab, Bitbucket, Gerrit,
Gitea or Forgejo, any self-hosted git server, or no server at all, mixed
within one feature.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/images/how-it-works-dark.svg">
  <source media="(prefers-color-scheme: light)" srcset="docs/images/how-it-works-light.svg">
  <img alt="On your machine, a coordinator session in the anchor repo writes the plan and the locked contracts into shared files. One worker session per repository, each in its own git worktree with a guard and a stop gate, reads those files and works in parallel, and opens a draft pull request on its repository's own host as soon as it starts: GitHub, Azure DevOps Server, GitLab, or a review packet for a local repo with no remote. The coordinator marks each pull request ready when its merge step comes. You approve the spec and plan, answer the workers' questions, and merge the ready pull requests in plan order." src="docs/images/how-it-works-light.svg">
</picture>

## The problem

Large features rarely live in one repository. Adding refunds might mean a new
endpoint in the billing service, a permission in the auth service, a screen
in the web client and a schema change in the repository that holds your API
specs. Those repositories may sit on different git hosts and belong to
different teams.

Coding agents are at their best inside one repository. Stretch them across
several and the same problems show up:

- **One session can't hold every repository.** Load five repositories into
  one conversation and the agent runs out of context. It also works without
  each repository's own instructions, hooks and test commands.
- **Parallel agents drift apart.** Give each repository its own agent and
  each one guesses at the interface between them. The billing service expects
  `amount_cents`, the web client sends `amount`, both test suites pass, and
  the feature breaks once both pull requests merge.
- **Agents change what they don't own.** A session edits a sibling
  repository, writes into a main checkout or pushes to the default branch.
- **Order matters, and nobody owns it.** The API change has to ship before
  the client that calls it, and feature flags have to turn on in sequence.
  Merge out of order and production runs half a feature.
- **Review becomes the bottleneck.** Every repository produces a pull
  request, every review produces more changes, and an agent that applies
  every comment can quietly undo the spec.
- **Decisions get lost.** Agents make many small choices nobody asked for,
  and by review time nobody remembers why.

## The approach

feature-coordinator runs the feature the way a tech lead runs a small team:
one plan, one owner per repository, agreed interfaces, and a person who signs
off on every step.

| Problem | What feature-coordinator does |
|---|---|
| One session can't hold every repository | A **coordinator** session in an *anchor* repository (where your specs live) plans the feature. Each repository gets its own **worker** session in its own git worktree, with that repository's instructions, hooks and test commands. Workers run in parallel. |
| Parallel agents drift apart | The plan carries the exact contract files: OpenAPI, protobuf, event schemas. Once the plan's pull request merges, `feature-workspace lock` pins each contract to its **git blob id**, so every worker builds against the same bytes. Changing a contract takes a new plan pull request, and only you can unlock one. |
| Agents change what they don't own | A **guard hook** keeps each session inside its own worktree and blocks force pushes, pushes to the default branch, merges and approvals. |
| Order matters | The plan sets the merge order as numbered steps. Every pull request stays a **draft** until its step comes; then the coordinator marks it ready, which tells reviewers it is next to merge. Agents can't merge: **you** merge each step with flags off, then turn the flags on in order. |
| Review becomes the bottleneck | Each worker opens its draft pull request as soon as it starts, so reviewers can comment while the work happens. A **stop gate** sends a worker back to work while its contract check or tests fail. Each worker **triages** review threads instead of applying every comment, sends changes that affect other repositories through the coordinator, and after three rounds stops to propose a different approach. |
| Decisions get lost | Every push carries a **decision block** that lists the choices the agent made on its own, and a decision log keeps them for the whole feature. |

The sessions coordinate through plain files instead of chat summaries: the
merged plan, the locked contracts, a mailbox between sessions and the
decision log. Any harness can read them, they survive restarts, and you can
inspect them at any time. Hooks enforce the rules in Claude Code and Copilot
CLI; [What is enforced, and how](#what-is-enforced-and-how) shows the
coverage in each harness.

Every agent session runs on your machine under your own credentials, and
cloud agents and services stay off unless you turn them on. The skills keep
the feature's work item current in your tracker (Azure Boards, Jira, GitHub
Issues, Linear or GitLab Issues) and post to your team chat (Teams, Slack or
Discord) only when you ask.

## How a feature runs

| Phase | What happens | Your call |
|---|---|---|
| 1. Start | `feature-workspace start` creates a worktree for each repository on the feature branch, plus the shared files | - |
| 2. Spec | The coordinator writes one spec with you and opens it as a draft pull request in the anchor repository, ready once you call it complete | Approve and merge |
| 3. Plan | The plan's pull request lists each repository's pull request with its merge step, the acceptance tests, the rollout order and the contract files | Approve and merge; the contracts lock |
| 4. Build | `feature-workspace dispatch` starts one worker per repository; each opens a draft pull request on its repository's host right away and builds its part in it | Answer questions |
| 5. Review | Reviewers comment on the drafts while the work happens; workers triage the threads and push fixes; changes that cross repositories go through the coordinator | Comment any time |
| 6. Merge and roll out | Step by step through the merge order: the coordinator marks the step's finished pull requests ready, reviewers approve them, you merge them with flags off; then flags turn on in order | Every merge and every flag |
| 7. Finish | A docs pull request records the decisions and the test proof; `feature-workspace finish` cleans up | Merge |

Inside a phase the agents work on their own, within the limits you set; the
phase ends when you make the call. The design and the research behind it are
in [docs/architecture.md](docs/architecture.md).

## When to use it

Use feature-coordinator when:

- one feature needs coordinated changes in **two or more repositories**,
  especially when they share an interface: an API, events, a schema or an
  SDK;
- the repositories live on **different git hosts**, or some have no remote
  at all;
- the agents need to run **on engineers' machines**, under their own
  credentials;
- you want agents working **in parallel** while **people** keep the
  approvals, the merges and the rollout.

A single agent session is enough when:

- the change fits in **one repository**: use your agent on its own, or with
  [superpowers](https://github.com/obra/superpowers) for the engineering
  workflow;
- the code lives in a **monorepo**: one session can see all of it;
- the change is **small** enough that writing a spec and a plan would take
  longer than the change itself.

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

`start` lays the workspace out like this:

```
<workspace>/                        (not a repository)
  platform-specs/.worktrees/PAY-42/   coordinator  - spec, plan, contracts, docs PRs
  auth-service/.worktrees/PAY-42/     worker       - auth-service PR
  billing-service/.worktrees/PAY-42/  worker       - billing-service PR
  .feature/PAY-42/                    local state  - contract lock, mailbox, briefs, proof
```

`$FW help` lists every command. Inside a feature worktree, `$FW where` says
which feature, role and files the session belongs to.

## Configure your team's stack

Commit `.feature-coordinator.conf` to the anchor repo:

```ini
tracker = jira                 # azure-boards | jira | github-issues | linear | gitlab-issues | none
tracker.url = https://acme.atlassian.net
code_host = auto               # per repo from origin; or github | azure-repos | gitlab | bitbucket | gerrit | gitea | local | other
code_host.ledger = azure-repos # a repo on a custom domain (e.g. Azure DevOps Server)
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

## Supported code hosts

| Host | Detected from `origin` | `fw status` PR column | Guard blocks merge and approve via | Reference |
|---|---|---|---|---|
| GitHub (incl. Enterprise Server) | `github` | `gh` | `gh`, REST | [github.md](skills/using-feature-coordinator/references/providers/github.md) |
| Azure DevOps Services and Server | `dev.azure.com`, `visualstudio.com`, `/_git/` | `az repos` | `az repos`, `az rest`, REST | [azure-devops.md](skills/using-feature-coordinator/references/providers/azure-devops.md) |
| GitLab (SaaS or self-managed) | `gitlab` | `glab` | `glab`, REST | [gitlab.md](skills/using-feature-coordinator/references/providers/gitlab.md) |
| Bitbucket Cloud | `bitbucket` | - | REST | [bitbucket.md](skills/using-feature-coordinator/references/providers/bitbucket.md) |
| Gerrit | port 29418, `gerrit` | - | `ssh ... gerrit review/submit`, `%submit`, REST | [gerrit.md](skills/using-feature-coordinator/references/providers/gerrit.md) |
| Gitea, Forgejo, Codeberg | `gitea`, `forgejo`, `codeberg.org` | - | `tea`, REST | [gitea.md](skills/using-feature-coordinator/references/providers/gitea.md) |
| Self-hosted git without pull requests | anything else (`other`) | review packet + git | pushes to the default branch | [local.md](skills/using-feature-coordinator/references/providers/local.md) |
| Local repo, no remote | no `origin`, or a folder path | review packet + git | merging in the main checkout | [local.md](skills/using-feature-coordinator/references/providers/local.md) |

Custom domains that detection cannot place get `code_host.<repo> = <host>`
in the team config. Every host also gets the host-independent protections:
no force pushes, no pushes to the default branch, no edits outside the
session's worktree.

Repositories must be git: worktrees are a git feature. Repos in TFVC,
Subversion, Perforce or Mercurial can join through a git bridge (git-tfs,
git-svn, git-p4, git-remote-hg), with the bridge's git repo as the
participant.

## What is enforced, and how

| Guarantee | Mechanism | Harnesses |
|---|---|---|
| A session edits only its own worktree | `worktree-guard` PreToolUse hook (file tools and shell commands: redirects, `cp`/`mv`/`rm`, `sed -i`, `git -C`, `cd` into other repos) | Claude Code, Copilot CLI; Codex via `--sandbox workspace-write` |
| Locked contract files do not change | guard hook on edits + `contract-check` in the Stop gate | Claude Code, Copilot CLI (Codex/Cursor/Gemini: the worker runs the check) |
| A worker cannot stop with failing checks | `feature-gate` Stop hook runs contract check + the repo's gate command, blocks once per state | Claude Code, Copilot CLI |
| No force pushes, no pushes to the default branch, no agent merges or approvals | guard hook (`git push --force`, `gh pr merge`, `az repos pr update --status completed`, `glab mr merge`, `tea pulls merge`, Gerrit submit and +2, REST merge/approve calls, auto-complete) | Claude Code, Copilot CLI |
| Contract unlocks and forced cleanup are human-only | guard hook denies `feature-workspace unlock` / `finish --force` | Claude Code, Copilot CLI |
| Tier 3 paths need your OK | `protected_paths` in the team config: Claude Code asks you; others deny with the reason | Claude Code, Copilot CLI |
| PRs stay drafts until their merge step | Workers open drafts (H1); only the coordinator marks PRs ready (H7), step by step; `fw status` shows draft or ready per PR | all (skills) |
| Decisions are visible | recording-decisions skill, PR template, decision log; add the CI check in [docs/team-setup.md](docs/team-setup.md) to make it deterministic | all |

The guard is a guardrail against mistakes, not a security boundary; pair it
with your harness's sandbox where you have one.

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
| finishing-a-multi-repo-feature | PRs are complete and wait for their merge step; approvals or merges are in; rollout; cleanup |

If superpowers is installed too, its engineering skills (brainstorming,
TDD, debugging, verification, code review) keep governing work inside each
repo.

## Development

```bash
bash tests/run-all.sh                 # hooks, workspace script, manifests, skill structure
claude plugin validate . --strict     # if Claude Code is installed
python3 docs/images/how-it-works.py   # regenerate the README diagram after editing it
```

CI runs the suite on Linux and on macOS's stock bash 3.2 and awk. See
[AGENTS.md](AGENTS.md) for conventions and [docs/porting.md](docs/porting.md)
for adding a harness or a provider.

## License

MIT. Packaging conventions adapted from obra/superpowers (MIT, Copyright (c)
2025 Jesse Vincent); see [NOTICE.md](NOTICE.md).
