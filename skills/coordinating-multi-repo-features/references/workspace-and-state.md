# Workspace and State Reference

Everything `feature-workspace` creates, and what each file is for. None of
it is tracked by git: the worktree folders are excluded through each repo's
`info/exclude`, and `.feature/` lives in the workspace folder, which is not a
repository.

## Layout

```
<workspace>/
  .feature/
    config                      optional personal overrides (key = value)
    <ID>/
      feature.env               FC_ID, FC_WORKSPACE, FC_ANCHOR, FC_CREATED
      config.env                team stack snapshot taken at start
      repos.tsv                 participants (see below)
      contracts.lock            locked contract files (after `lock`)
      unlocked.tsv              human-approved exceptions to the lock
      decisions.md              decision log (Tier 2 and 3)
      briefs/worker-<repo>.md   worker briefs (written by `dispatch`)
      briefs/brief-<date>.md    briefs for your human partner
      mail/<who>/*.md           unread messages; read ones move to read/
      gates/<repo>.*            Stop-gate fingerprints and last log
      proof/<repo>/             verification evidence
      reviews/<repo>.md         review packets for repos without pull requests
    _archive/<ID>-<stamp>/      state of finished features
  <anchor>/.worktrees/<ID>/     coordinator worktree
  <repo>/.worktrees/<ID>/       worker worktrees
  <anchor>/.worktrees/<ID>-code/  worker worktree when the anchor also ships code
```

Each worktree also has a record in its repository's git directory,
`<git-common-dir>/feature-coordinator/<worktree>.env`, which the hooks read to
learn which feature, role and state folder a session belongs to.

## Branches

With `branch_prefix` (default `feat/`):

| Branch | Where | Purpose |
|---|---|---|
| `<prefix><ID>-spec` | anchor | Spec PR |
| `<prefix><ID>-plan` | anchor | Plan PR (contract lock) |
| `<prefix><ID>-docs` | anchor | Docs, decisions and proof PR |
| `<prefix><ID>` | each worker repo | That repo's code PR |
| `<prefix><ID>--sub-<slug>` | a worker repo | Stacked sub-PR into `<prefix><ID>` |

The anchor worktree starts on the `-spec` branch. After the spec merges,
switch it to a new `-plan` branch from the updated default branch, and later
to `-docs`.

## repos.tsv

Tab-separated, coordinator row first:

| Column | Meaning |
|---|---|
| 1 | who: `coordinator` or the repo name |
| 2 | repository name |
| 3 | role: `anchor` or `worker` |
| 4 | main checkout path |
| 5 | worktree path |
| 6 | branch |
| 7 | gate command (empty: contract check only) |
| 8 | code host: github, azure-repos, gitlab, bitbucket, gerrit, gitea, local or other |

Gate precedence: `--gate repo=cmd` at start > `gate.<repo>` in
`<workspace>/.feature/config` > `gate.<repo>` in the anchor's
`.feature-coordinator.conf` > `gate` in the repo's own
`.feature-coordinator.conf`.

## contracts.lock

```
# feature=<ID>
# ref=origin/main
# commit=<sha of the merged plan>
# locked_at=<UTC time>
<repo>\t<path in repo>\t<path of the copy in the anchor>\t<git blob id>
```

`apply-contract` writes each blob into the worker's worktree;
`contract-check` compares the worktree file's blob id with the lock;
`unlock` (human only) adds an exception to `unlocked.tsv` until the next
`lock`.

## Mail

One file per message: `From:`, `To:`, `Date:`, `Subject:` headers, a blank
line, then the body. `mail inbox` prints unread messages and moves them to
`read/` (keep them with `--keep`). The mailbox works the same on every
harness; where a harness can also message other sessions directly, use that
only to nudge the recipient to read its mail.

## Team stack keys

`tracker`, `tracker.url`, `tracker.project`, `code_host`, `code_host.<repo>`, `chat`,
`chat.channel`, `chat.webhook_env`, `branch_prefix`, `docs_dir`,
`default_cli`, `coordinator_model`, `worker_model`, `model.<repo>`,
`effort`, `protected_paths`, `gate.<repo>` (anchor or workspace file),
`gate` (a repo's own file). See
`../../using-feature-coordinator/references/providers/README.md`.

Resolution: environment (`FC_TRACKER`, ...) > `<workspace>/.feature/config` >
`<anchor>/.feature-coordinator.conf` > defaults. `start` snapshots the result
into `config.env`; `config <ID> --refresh` re-reads it but keeps
`branch_prefix` and `docs_dir`, which a running feature depends on.

## Session environment

Sessions opened with `launch` or `dispatch` get `FC_SESSION_WORKTREE` set to
their worktree, so the hooks know who they are even after the agent's shell
changes directory. Claude Code sessions also carry `CLAUDE_PROJECT_DIR`.

| Variable | Effect |
|---|---|
| `FC_GUARD=off` | Disable the worktree guard for that session |
| `FC_GATE=off` | Disable the Stop gate for that session |
| `FC_GATE_TIMEOUT` | Gate time limit in seconds (default 840; 25 under Copilot CLI, whose hooks time out sooner) |
| `FC_GATE_MAX_BLOCKS` | Consecutive blocks before the gate lets a stop through (default 3) |
| `FC_GUARD_DEBUG=1` | The guard explains each decision on stderr (troubleshooting) |
