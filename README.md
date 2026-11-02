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

### What we want

1. **One engineer, one feature, many repositories.** You describe the feature
   once, and agents build it in every repository it touches, in parallel.
2. **Each change fits its repository.** It follows that repository's own
   instructions, conventions, hooks and tests, and its own code owners
   review it.
3. **The pieces fit together.** Every repository implements the same
   interface, byte for byte, so the parts work once they merge.
4. **People make the calls that matter.** The spec, the plan, contract
   changes, approvals, merges and rollout stay with people, and agents ask
   instead of guessing.
5. **Review converges.** Reviewers can comment early, feedback is weighed
   instead of applied blindly, and no pull request bounces between reviewer
   and agent indefinitely.
6. **Nothing is hidden.** Every choice an agent made on its own is written
   down where reviewers see it.
7. **It runs where the code is.** On engineers' machines, under their own
   credentials, with repositories on any git host.

### What gets in the way

Published guidance on building agents describes the quality and fidelity
problems that stand between today's coding agents and those goals:

- **Context rot.** A model recalls what is in its context less accurately as
  the context grows ([Anthropic, *Effective context engineering*][context]),
  and Claude Code's best practices start from the same constraint ([Claude
  Code best practices][bp]). One session holding five repositories sees each
  of them less clearly.
- **The telephone game.** When agents hand work to each other, detail gets
  lost "with each handoff degrading fidelity" ([Anthropic, *When to fold
  subagents*][fold]). A worker that builds from someone's summary of the plan
  drifts from the plan.
- **Conflicting implicit decisions.** "Actions carry implicit decisions, and
  conflicting decisions carry bad results" ([Cognition, *Don't Build
  Multi-Agents*][cognition]). Across repositories, that is a billing service
  that expects `amount_cents` and a web client that sends `amount`: both test
  suites pass, and the feature breaks once both merge. Work with many
  dependencies between agents is a poor fit for multi-agent systems
  ([Anthropic, *Multi-agent research system*][research]), and the choices
  agents make on their own are invisible unless someone writes them down.
- **Subagents don't belong in other repositories.** A Claude Code subagent
  "starts in the main conversation's current working directory" and cannot
  ask you questions ([Claude Code subagents docs][subagents]). Sent into a
  sibling repository, it works without that repository's setup and guesses
  where it should ask.
- **Instructions are advisory.** "Stay in your repository" and "never merge"
  written in a prompt hold most of the time. Hooks, by contrast, "are
  deterministic and guarantee the action happens" ([Claude Code best
  practices][bp]).
- **"Looks done" isn't done.** Without a check it can run, an agent stops
  when the work looks done; the typical result is "a plausible-looking
  implementation that doesn't handle edge cases" ([Claude Code best
  practices][bp]).
- **Review that never ends.** Anthropic's Claude Code team saw one pull
  request go through more than fifty rounds of review and fixes overnight
  ([Anthropic, *How the Claude Code team does code review*][review]), and a
  reviewer asked to find gaps "will usually report some" ([Claude Code best
  practices][bp]). Multiply that by one pull request per repository.
- **Order.** The API change has to merge before the client that calls it,
  and new behavior has to switch on in sequence. Out of order, production
  runs half a feature.

## The approach

feature-coordinator runs the feature the way a tech lead runs a small team:
one plan, one owner per repository, agreed interfaces, and a person who signs
off on every step. Each design choice answers one or more of the problems
above.

1. **Split the work by repository, not by role.** A coordinator session plans
   the feature in the *anchor* repository (where your specs live); every
   other repository gets one full worker session in its own git worktree, and
   the workers run in parallel. Anthropic's guidance is to divide agents by
   context, giving each "a piece of work that needs little from the rest of
   the system", and otherwise to keep one loop with skills, which
   "frequently outperformed" subagent designs ([*When to fold
   subagents*][fold]). A repository whose interfaces are locked is that kind
   of piece. A full session, unlike a subagent, starts in its own repository,
   loads that repository's instructions and hooks, and can ask you directly.
2. **Pass documents, not summaries.** Workers read the merged spec, the plan
   and the locked contract files themselves; sessions talk through a mailbox
   and a decision log on disk. Anthropic's research system has subagents
   "store their work in external systems, then pass lightweight references
   back" to avoid the telephone game ([*Multi-agent research
   system*][research]), and its context guidance keeps notes outside the
   context window ([*Effective context engineering*][context]).
3. **Settle shared decisions before parallel work starts.** A spec pull
   request, then a plan pull request with the exact contract files (OpenAPI,
   protobuf, event schemas), each repository's acceptance tests, the merge
   order and the rollout. When the plan merges, `feature-workspace lock` pins
   every contract to its git blob id, so every worker builds against the same
   bytes, and changing one takes a new plan pull request. This is "explore
   first, then plan, then code" ([Claude Code best practices][bp]) across
   repositories, and Cognition's first principle, share context, made
   concrete: the decisions every worker depends on are made once, in writing
   ([*Don't Build Multi-Agents*][cognition]).
4. **Enforce the rules that must always hold.** A guard hook keeps each
   session inside its worktree and blocks force pushes, pushes to the default
   branch, merges, approvals and edits to locked contracts. A stop gate runs
   the contract check and the repository's tests before a worker may stop.
   These are hooks rather than instructions because hooks are deterministic
   ([Claude Code best practices][bp]). [What is enforced, and
   how](#what-is-enforced-and-how) shows the coverage in each harness.
5. **Verify with evidence and fresh eyes.** Workers prove their slice with the
   plan's acceptance tests, save the evidence, and have a reviewer with a
   fresh context check the diff before they report it complete. Claude Code's
   best practices call for a check the agent can run, evidence instead of
   claims, and review in a fresh context "since Claude won't be biased toward
   code it just wrote" ([Claude Code best practices][bp]).
6. **Make review converge.** Workers sort review threads into buckets instead
   of applying every comment, send changes that affect other repositories
   through the coordinator, ask for re-review of the new diff only, and after
   three rounds stop to propose a different approach. These are the
   convergence rules of Anthropic's own code review, which cut the mean
   number of reviews a pull request needs to pass from 2.08 to 1.32 ([*How
   the Claude Code team does code review*][review]).
7. **Keep people on the decisions, and make every decision visible.** Pull
   requests open as drafts so people can comment while the work happens; one
   becomes ready only when its step in the merge order comes. Agents never
   merge, approve or unlock, and feature flags and rollout follow the plan.
   Every push carries a decision block listing the choices the agent made on
   its own, and a decision log keeps them for the whole feature. As in
   Anthropic's review process, an agent's approval never counts as a
   person's ([*How the Claude Code team does code review*][review]).
8. **Use the simplest shape that works.** Parallel sessions only across
   repositories, skills instead of extra agents inside each one, and bounded
   autonomy within each phase. Anthropic's advice is to "start with the
   simplest pattern ... that could work" ([*When to fold subagents*][fold]),
   and multi-agent systems use about 15 times the tokens of a chat
   ([*Multi-agent research system*][research]), so every extra session has to
   earn its cost. One per repository does, because that is where the work is
   independent.

Every agent session runs on your machine under your own credentials, and
cloud agents and services stay off unless you turn them on. The skills keep
the feature's work item current in your tracker (Azure Boards, Jira, GitHub
Issues, Linear or GitLab Issues) and post to your team chat (Teams, Slack or
Discord) only when you ask. The research behind these choices and the
requirements they trace to are in [docs/architecture.md](docs/architecture.md).

[context]: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
[fold]: https://claude.com/blog/building-agents-when-to-fold-subagents-into-your-main-agent-loop
[research]: https://www.anthropic.com/engineering/multi-agent-research-system
[review]: https://claude.dev/blog/solving-code-review-at-anthropic/
[bp]: https://code.claude.com/docs/en/best-practices
[subagents]: https://code.claude.com/docs/en/subagents
[cognition]: https://cognition.com/blog/dont-build-multi-agents

## How a feature runs

| Phase | What happens | Your call |
|---|---|---|
| 1. Start | `feature-workspace start` creates a worktree for each repository on the feature branch, plus the shared files | - |
| 2. Spec | The coordinator writes one spec with you and opens it as a draft pull request in the anchor repository, ready once you call it complete | Approve and merge |
| 3. Plan | The plan's pull request lists each repository's pull request with its merge step, the acceptance tests, the contract files, and the rollout: whether to use feature flags, where each starts, and their order | Approve and merge; the contracts lock |
| 4. Build | `feature-workspace dispatch` starts one worker per repository; each opens a draft pull request on its repository's host right away and builds its part in it | Answer questions |
| 5. Review | Reviewers comment on the drafts while the work happens; workers triage the threads and push fixes; changes that cross repositories go through the coordinator | Comment any time |
| 6. Merge and roll out | Step by step through the merge order: the coordinator marks the step's finished pull requests ready, reviewers approve them, you merge them; then, if the plan uses feature flags, you change them in the order it sets | Every merge and every flag change |
| 7. Finish | A docs pull request records the decisions and the test proof; `feature-workspace finish` cleans up | Merge |

Inside a phase the agents work on their own, within the limits you set; the
phase ends when you make the call.

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
