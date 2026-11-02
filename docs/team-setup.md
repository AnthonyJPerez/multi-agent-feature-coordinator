# Team Setup

What a team does once so every engineer's sessions use the right tracker,
code host and chat, and the code host enforces what the skills assume.

## 1. Pick the anchor repository

The repo that holds feature specs and plans - usually a platform, API or
architecture-docs repo. Commit `.feature-coordinator.conf` at its root
(annotated example:
`skills/using-feature-coordinator/references/providers/example.feature-coordinator.conf`).

## 2. Configure the stack

### GitHub + GitHub Issues + Slack

```ini
tracker = github-issues
code_host = github
chat = slack
chat.webhook_env = FC_SLACK_WEBHOOK
branch_prefix = feat/
```

### Azure Repos + Azure Boards + Teams

```ini
tracker = azure-boards
tracker.url = https://dev.azure.com/contoso
tracker.project = Payments
code_host = azure-repos
chat = teams
chat.webhook_env = FC_TEAMS_WEBHOOK
branch_prefix = users/
protected_paths = azure-pipelines.yml, **/auth/**
```

### GitHub + Jira + Teams

```ini
tracker = jira
tracker.url = https://acme.atlassian.net
tracker.project = PAY
code_host = github
chat = teams
chat.webhook_env = FC_TEAMS_WEBHOOK
```

### GitLab + Jira + Slack

```ini
tracker = jira
tracker.url = https://acme.atlassian.net
code_host = gitlab
chat = slack
chat.webhook_env = FC_SLACK_WEBHOOK
```

### Mixed hosts, custom servers and local repos

One feature can span repos on different hosts. Leave `code_host = auto` and
each repo's host is detected from its `origin` URL; correct the ones
detection cannot place:

```ini
code_host = auto
code_host.ledger = azure-repos       # Azure DevOps Server on a company domain
code_host.pricing-engine = gerrit    # Gerrit without "gerrit" in its hostname
code_host.ml-pipeline = gitlab       # self-managed GitLab at git.acme.internal
code_host.prototypes = local         # no remote; reviewed on this machine
```

- **Azure DevOps Server (on-prem)**: URLs containing `/_git/` are detected;
  `az` needs `--org https://<server>/<collection>` for status lookups.
- **Gerrit**: give the feature ID as the change topic
  (`refs/for/main%topic=<ID>`) so one query shows the feature's changes in
  every Gerrit repo.
- **Repos without pull requests** (`local`, or `other` for a plain git
  server): work is reviewed through a review packet in
  `.feature/<ID>/reviews/`, and the engineer merges in the main checkout.
- A repo can declare its own host in its own `.feature-coordinator.conf`
  (`code_host = gerrit`), which helps when the same repo joins features
  anchored in different places.
- Only git repositories can take part. Bridge others with git-tfs (TFVC),
  git-svn, git-p4 or git-remote-hg and register the bridged git repo.

### Gates and models

```ini
gate.billing-service = make test lint
gate.web = npm test -- --watch=false && npm run lint
model.billing-service = opus        # Claude Code worker model for risky repos
effort = high
```

A repo can also own its gate: `gate = ./scripts/ci-fast.sh` in its own
`.feature-coordinator.conf`. Keep gates fast (a few minutes): the Stop hook
runs them whenever a worker finishes a turn with changes, and Copilot's
default hook timeout is 30 seconds.

### Personal overrides

An engineer puts `key = value` lines in `<workspace>/.feature/config`, or
sets `FC_*` variables (`FC_DEFAULT_CLI=copilot`, `FC_BRANCH_PREFIX=users/ana/`).
Check with `fw config --anchor <anchor-repo>`.

### Secrets

Never in config files. Webhook URLs and tokens go in each engineer's
environment (shell profile, OS keychain helper, or the team's secret tool);
`chat.webhook_env` only names the variable.

## 3. Repository hygiene

In every participating repo:

- **Instructions**: `CLAUDE.md` / `AGENTS.md` / `.github/copilot-instructions.md`
  as the team already uses; keep them short. Workers load them because they
  run inside the repo.
- **PR template** with the sections from
  `skills/recording-decisions/templates/pull_request_template.md`, at the
  host's location (provider reference H9).
- **Code owners / path reviewers** for contract files, auth, billing, CI
  and dependency manifests.
- **`.worktreeinclude`** listing gitignored files a fresh worktree needs
  (for example `.env.local`); `start` copies matches into each worktree.
- Nothing to add to `.gitignore`: `start` adds `.worktrees/` to the repo's
  local `info/exclude`.

## 4. Code-host approval rules

Match the review model the skills assume (provider reference H8 has the
exact setting names per host):

| Rule | Why |
|---|---|
| At least one human approval; two for high-risk paths | Agent approvals never count |
| Approvals reset or dismissed when new commits are pushed | An approval covers one commit |
| Most recent pusher cannot approve; author cannot approve | Cross-service code PRs need a non-author human |
| Code owners required on contract and protected paths | Tier 3 paths get the right eyes |
| No direct pushes to the default branch; no force pushes | Matches the guard hook |

A zero-approval low-risk tier is reasonable only for authors on a trusted
list, with automated and security review green - set it up as a separate,
narrow rule if you want it.

Feature PRs open as drafts and stay drafts until their merge step in the
plan comes; the coordinator then marks them ready. Reviewers can comment on
a draft at any time, and approvals are asked for once the PR is ready. Two
host behaviors make that work without extra settings: GitHub requests code
owners when a draft is marked ready, not before; Azure DevOps adds required
reviewers, runs build validation policies and opens voting when a draft is
published. If your CI skips drafts, let it run on them (or on branch pushes)
so workers see failures while they build. On Azure DevOps, workers can queue
a draft's build validation themselves (provider reference H7).

## 5. Make the decision block deterministic (optional)

The skills put an "Assumptions & Autonomous Decisions" section in every
feature PR. A CI check turns that into a gate.

GitHub Actions (`.github/workflows/decision-block.yml`):

```yaml
name: decision-block
on:
  pull_request:
    types: [opened, edited, synchronize, reopened, ready_for_review]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - name: PR body has a decision block
        env:
          BODY: ${{ github.event.pull_request.body }}
        run: |
          printf '%s' "$BODY" | grep -q '^#\{2,3\} Assumptions & Autonomous Decisions' \
            || { echo "Add an 'Assumptions & Autonomous Decisions' section to the PR description."; exit 1; }
```

Azure Pipelines (PR validation build): read the description with
`az repos pr show --id $(System.PullRequest.PullRequestId) --query description -o tsv`
using the build's access token, and fail the same way.

## 6. Distribute the plugin

- **Claude Code**: commit `extraKnownMarketplaces` + `enabledPlugins` in each
  repo's `.claude/settings.json` (see the README). For organization-wide
  enforcement, set the same in managed settings, plus
  `permissions.disableBypassPermissionsMode: "disable"` and
  `allowManagedHooksOnly: true` (hooks of force-enabled plugins still run).
- **Copilot CLI**: `copilot plugin marketplace add <org>/feature-coordinator`
  on each machine, or your organization's plugin distribution. Consider
  organization policies for session sync, Memory and Dreaming.
- **Codex**: `codex plugin marketplace add <org>/feature-coordinator`, and the
  `[plugins."feature-coordinator@feature-coordinator"]` entry in the repo's
  `.codex/config.toml`.
- Pin versions in your marketplace and bump with `scripts/bump-version.sh`.

## 7. Pilot

Run two or three real features with one team before rolling out; the
checklist is at the end of [architecture.md](architecture.md).
