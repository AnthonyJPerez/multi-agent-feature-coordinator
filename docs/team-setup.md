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

### Mixed hosts

Leave `code_host = auto`: each repo's host is detected from its `origin`
URL (`dev.azure.com`/`visualstudio.com`, `github`, `gitlab`, `bitbucket`).
Set it explicitly for self-hosted hosts with unusual names.

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

## 5. Make the decision block deterministic (optional)

The skills put an "Assumptions & Autonomous Decisions" section in every
feature PR. A CI check turns that into a gate.

GitHub Actions (`.github/workflows/decision-block.yml`):

```yaml
name: decision-block
on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
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
