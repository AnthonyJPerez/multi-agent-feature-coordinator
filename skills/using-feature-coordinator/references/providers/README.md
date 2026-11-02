# Team Stack and Provider References

The skills say what to do ("open a draft PR", "mark the work item in
progress"). Which tool does it depends on the team's stack, set in
configuration and never in the skills.

## Configuration

A team commits `.feature-coordinator.conf` at the root of its anchor repo.
An engineer can override any key for their own machine in
`<workspace>/.feature/config`, or for one shell with an environment variable.
Resolution, first match wins:

1. environment variable (`FC_TRACKER`, `FC_CODE_HOST`, ...)
2. `<workspace>/.feature/config`
3. `<anchor repo>/.feature-coordinator.conf`
4. defaults

Format: `key = value` lines, `#` starts a comment line. An annotated example
is `example.feature-coordinator.conf` in this folder.

| Key | Values | Default |
|---|---|---|
| `tracker` | `azure-boards`, `jira`, `github-issues`, `linear`, `gitlab-issues`, `none` | `none` |
| `tracker.url` | Base URL (Azure DevOps organization, Jira site) | - |
| `tracker.project` | Project or team key | - |
| `code_host` | `auto`, `github`, `azure-repos`, `gitlab`, `bitbucket`, `gerrit`, `gitea`, `local`, `other` | `auto` (detected per repo from its `origin`) |
| `code_host.<repo>` | Same values, for one repo (custom domains, on-prem servers) | - |
| `chat` | `teams`, `slack`, `discord`, `none` | `none` |
| `chat.channel` | Channel name or ID, for messages only | - |
| `chat.webhook_env` | Name of the environment variable holding the webhook URL | - |
| `branch_prefix` | e.g. `feat/`, `feature/`, `users/<alias>/` | `feat/` |
| `docs_dir` | Folder for feature docs in the anchor repo | `docs/features` |
| `default_cli` | `claude`, `copilot`, `codex` | `claude` |
| `coordinator_model` | Claude Code model for the coordinator | `opus` |
| `worker_model` | Claude Code model for workers | `sonnet` |
| `model.<repo>` | Claude Code model for one repo's worker | `worker_model` |
| `effort` | `low`, `medium`, `high`, `xhigh`, `max` | `high` |
| `protected_paths` | Comma-separated globs needing your human partner's OK | - |
| `gate.<repo>` | Gate command for one repo | - |

A repository's own `.feature-coordinator.conf` may set `gate = <command>`
and `code_host = <host>` for itself.

## Repos on different hosts

Every repository in a feature has its own code host, and they may all
differ: one feature can touch a GitHub repo, an Azure DevOps Server repo on
the company network, a Gerrit project and a local repo with no remote at all.
For each repo, the first of these wins:

1. `code_host.<repo>` in `<workspace>/.feature/config`
2. `code_host.<repo>` in the anchor's `.feature-coordinator.conf`
3. `code_host` in the repo's own `.feature-coordinator.conf`
4. a team-wide `code_host` other than `auto`
5. detection from the repo's `origin` URL:

| origin | host |
|---|---|
| none, a folder path, `file://` | `local` |
| `dev.azure.com`, `*.visualstudio.com`, any URL with `/_git/` (Azure DevOps Server) | `azure-repos` |
| contains `github` (github.com, GitHub Enterprise Server) | `github` |
| contains `gitlab` | `gitlab` |
| contains `bitbucket` | `bitbucket` |
| port `29418` or contains `gerrit` | `gerrit` |
| contains `gitea`, `forgejo`, `codeberg.org` | `gitea` |
| anything else | `other` |

`fw config <ID>` lists each repo's host. Hosts on custom domains
(`git.acme.internal`) need `code_host.<repo>`.

Only git repositories are supported: worktrees are a git feature. Repos in
other version control systems (TFVC, Subversion, Perforce, Mercurial) can
take part through a git bridge such as git-tfs, git-svn or git-p4, with the
bridge's git repo as the participant.

**Never put secrets in these files.** Webhook URLs and tokens live in
environment variables; the config only names the variable.

Check the effective values: `fw config --anchor <repo>` before a feature
starts, `fw config <ID>` during one.

## Which reference to read

| Setting | Reference |
|---|---|
| `code_host = github`, `tracker = github-issues` | `github.md` |
| `code_host = azure-repos`, `tracker = azure-boards` | `azure-devops.md` |
| `code_host = gitlab`, `tracker = gitlab-issues` | `gitlab.md` |
| `code_host = bitbucket` | `bitbucket.md` |
| `code_host = gerrit` | `gerrit.md` |
| `code_host = gitea` (Gitea, Forgejo, Codeberg) | `gitea.md` |
| `code_host = local` or `other` (no pull-request system) | `local.md` |
| `tracker = jira` | `jira.md` |
| `tracker = linear` | `linear.md` |
| `chat = teams` | `teams.md` |
| `chat = slack` | `slack.md` |
| `chat = discord` | `discord.md` |

Mixed stacks are normal (GitHub code with Jira tickets and Teams chat, for
example): read one reference per role, and one code-host reference per host
your feature touches.

## Action vocabulary

Skills refer to these actions by code. Each reference implements the ones
its provider supports and says plainly when one is not available.

**Tracker**

| Code | Action |
|---|---|
| T1 | Read a work item (title, description, acceptance criteria, state) |
| T2 | Mark it in progress and assigned to your human partner |
| T3 | Link a PR to it |
| T4 | Comment on it |
| T5 | Move it to done, or leave it for the merge integration to close |

**Code host**

| Code | Action |
|---|---|
| H1 | Open a draft PR (title, body from file, base branch) |
| H2 | PR status: state, draft, approvals, checks; find open PRs touching paths |
| H3 | Read review threads with file, line and resolution state |
| H4 | Reply in a thread, or comment on the PR |
| H5 | Resolve a thread |
| H6 | Open a stacked sub-PR (base = the feature branch) |
| H7 | Mark a draft PR ready for review (active), or turn it back into a draft |
| H8 | Approval rules the team should enable (settings, not commands) |
| H9 | Where the PR template file lives |

**Chat**

| Code | Action |
|---|---|
| C1 | Post a message your human partner approved |
| C2 | Read replies to it |

## Rules that hold on every provider

- Act as your human partner's identity through their own CLI login or MCP
  connection. Never ask for, store or print tokens.
- Never merge, approve, complete, or set auto-complete or auto-merge. The
  guard hook blocks the common commands; the rule covers every other route
  too (web APIs, MCP tools).
- Every PR opens as a draft (H1), so people can comment while the work is in
  progress. The coordinator marks a feature PR ready (H7) only when its merge
  step in the plan comes; a worker may mark its own stacked sub-PRs ready. A
  ready PR that needs a large change goes back to draft (H7).
- Write PR bodies, replies and message payloads to files under
  `.feature/<ID>/` (the `<state>` folder), never into a worktree, so they
  cannot end up in a commit.
- Prefer a provider's MCP server when your human partner has one connected;
  the CLI commands here are the fallback that always works locally.
- If a command here fails because a flag changed, check `--help` and the
  provider's docs, and tell your human partner what differed.
