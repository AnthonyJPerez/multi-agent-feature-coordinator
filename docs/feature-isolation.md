# Running Several Features Side by Side

**Status: design for review. Nothing in this document is implemented yet.**

An engineer usually has several features in flight, each with its own agent
team: a coordinator session and one worker session per repository. The teams
share one machine, one workspace and often the same repositories. This
document describes how the plugin keeps those teams apart, what it found
shared today, and the decisions that need your review before implementation.

## Goal

Each feature's team works as if it were alone on the machine:

- **It sees the full history and its own feature.** In every repository it
  works in, a feature has the default branch with its full history, the tags,
  and its own branches (spec, plan, code, docs, sub-PRs). Another feature's
  work reaches it when that work merges into the default branch. This is how a
  feature sees incoming changes that may break it or change its direction.
- **It does not see other features' branches.** Other features' in-flight
  branches, commits and uncommitted work stay out of its repositories.
- **The network stays open.** No agent tool runs with network restrictions:
  research, package installs, code hosts, trackers and local services keep
  working.

"Kept apart" means two things. Both are about accidents, not a hostile agent:

1. **No corruption.** A team never writes into another feature's
   repositories, state folder, branches or sessions, and never changes
   repository state that another feature uses (a stash, repository config).
2. **No status leaks.** A team never reads another feature's private state:
   - its `.feature/<ID>/` folder (briefs, mail, decision log, research,
     proof);
   - its branches and commits, before they merge;
   - the uncommitted contents of its working copies;
   - its sessions' messages and memory.

Out of scope: OS sandboxes, containers or VMs (option D), network isolation,
separate credentials per feature, CPU and memory limits, and an agent set on
getting around the rules (for example a script that opens files itself).
Like the existing guard, this is a guardrail against mistakes, not a
security boundary.

## Territory

Each feature gets its own clone of every repository it works in (see
[One clone per feature](#1-one-clone-per-feature)). A *working copy* below
means that clone's checkout, at `<repo>/.worktrees/<ID>` as today. For a
session of feature F:

| Area | Access |
|---|---|
| This session's working copy | read and write |
| F's other working copies | read (writes blocked, as today) |
| F's state, `.feature/F/` | read and write |
| Git in F's clones: the default branch's full history, tags and F's own branches | read; F changes only its own branches |
| Main checkouts | read files; writes and git commands blocked |
| `.feature/config`, `.feature/_archive/` | read |
| Another feature's state folder, working copies, branches, sessions and `fw` commands | none |
| Everything outside the workspace | unchanged |

`.feature/` folders of other workspaces count as other features too.

## What happens today

This is what the current guard does for a session of feature A-1, in a
workspace where A-1 and B-2 share a repository (probe run against this
repository's test workspace):

| Action by a session of A-1 | Today | Proposed |
|---|---|---|
| Write a file in B-2's worktree | blocked | blocked |
| Write into B-2's state folder (file tool or shell redirect) | allowed | blocked |
| Read B-2's state folder | allowed | blocked |
| `cat` a file in B-2's worktree, or `git -C <B-2's worktree> status` | allowed | blocked |
| `grep -r` from the main checkout, which descends into every feature's worktree | allowed | blocked, with a hint |
| `fw mail B-2`, `fw dispatch B-2`, `fw status B-2`, `fw list` | allowed | blocked |
| `git branch -a`, `git log --all` | list B-2's branches and commits | list only A-1's branches and the default branch |
| `git log`, `git diff`, merge, rebase or reset against B-2's branch | allowed | not possible: B-2's branches are not in A-1's clones, and fetching them is blocked |
| Push to or delete B-2's branch | allowed | blocked |
| `git stash pop` | can pop B-2's stash | uses A-1's own stash |
| `git config user.email ...` | changes B-2's config too | changes A-1's clone only |
| `git worktree remove` on B-2's worktree | allowed | blocked |
| `SendMessage` to B-2's coordinator, `ListAgents`, `EnterWorktree` into B-2's worktree | not seen by the guard | blocked |

The stash and config rows are real cross-feature corruption, not just
theory. Linked worktrees of a repository share one stash, one config and
every branch. In a test repository, a stash made in B-2's worktree appeared
in A-1's `git stash list` as "WIP on" B-2's branch. Running `git stash pop`
in A-1 then applied B-2's uncommitted change to A-1's worktree. A
`git config` run in A-1 also changed the value B-2 sees.

The research also found channels inside the agent tools that the guard
cannot see:

- **Claude Code cross-session messaging is on by default** (v2.1.224 and
  later). `ListAgents` lists your other local sessions and their working
  directories, and `SendMessage` reaches them. Claude may also send a message
  without being asked; one example in the docs is telling the sessions in
  parallel worktrees of a repository what has landed. By default, a
  receiving session that prompts for permissions delivers these messages.
- **Claude Code auto memory is per repository** and shared by all of its
  worktrees. What one feature's worker records is loaded by the next
  feature's worker in that repository.
- **Claude Code "Yes, and don't ask again" approvals** given in a worktree
  are saved in the main checkout's `.claude/settings.local.json`, so they
  apply to every feature's worktree of that repository. A hook block still
  wins over allow rules.
- **Codex runs none of the plugin's hooks.** `.codex-plugin/plugin.json`
  sets `"hooks": {}`, which Codex reads as an empty inline hook list, so it
  never reads the default `hooks/hooks.json`. Codex's sandbox is the only
  protection there, and it only blocks writes.
- **Codex sessions start with the network off.** `--sandbox workspace-write`
  disables network access unless `sandbox_workspace_write.network_access` is
  set. That conflicts with "the network stays open".
- **Codex commits in a linked worktree hit the sandbox.** Codex makes the git
  directory that a worktree's `.git` file points to read-only. This holds even
  inside another writable root, such as the `--add-dir <git dir>` the launcher
  passes, unless that exact path is also added. `git add` and `git commit` then
  need an approval to run outside the sandbox. This comes from Codex's source;
  a live test should confirm it.
- **Codex sessions can share one background server.** Unless a session starts
  with `--no-daemon` (or certain overrides), Codex's terminal UI attaches to a
  shared server. The request that starts a session there carries its
  directory and sandbox settings, not its environment (read from the source,
  not tested), so `FC_SESSION_WORKTREE` may not reach the session's hooks.
- **Copilot CLI keeps one session store per user**, and it can consult that
  store about past work in any repository. Copilot Memory is per repository.
  Hooks see neither.
- **Docker Compose project names collide.** With no `name:` in the compose
  file, Compose names a project after the compose file's folder. At a
  worktree's root that folder is named after the feature ID in every
  repository, so one feature's stacks in different repositories become one
  project. With a `name:`, every feature's worktree of a repository shares
  one project instead. Either way, a `docker compose down -v` can remove
  another stack's containers and volumes.

## Design

The design has four parts:

1. **One clone per feature.** Git itself keeps other features' branches,
   stash and config out of a feature's repositories.
2. **The guard.** It works in every session that starts inside a feature's
   working copy, however the session was launched, and it sees features
   created after the session started.
3. **The launcher.** It adds per-session settings in each agent tool.
4. **Conventions.** The skills, `fw incoming` and the runtime names.

### 1. One clone per feature

Today `fw start` adds a linked worktree of each main checkout, so every
feature shares the repository's branches, stash and config. Instead,
`fw start` gives each feature its own clone of each repository, in the same
place as today (`<repo>/.worktrees/<ID>`).

**How the clone is made.** It is cloned from the main checkout with hard
links (`git clone --local --single-branch`), so it costs little disk and
does not depend on the main checkout afterwards. Then its `origin` points
at the main checkout's remote. For a repository without a remote, `origin`
is the main checkout itself, and the feature pushes its branches there.

**What it fetches.** Only the default branch with its full history, the
tags, and the feature's own branches. In a test, the remote also had:

- another feature's branch;
- the branch of a feature whose ID starts with the same characters;
- a release branch.

The clone's `git branch -a` and `git log --all` still showed only `main` and
the feature's own branches.

**Branch names.** They move under a folder per feature, so that one fetch
rule matches exactly that feature's branches:

| Branch | Where |
|---|---|
| `<prefix><ID>/code` | each repository's code PR |
| `<prefix><ID>/spec`, `/plan`, `/docs` | the anchor |
| `<prefix><ID>/sub-<slug>` | stacked sub-PRs |

Today's names can't be matched exactly. A fetch rule for `feat/PAY-42*`
also matches `feat/PAY-421`. Naming `feat/PAY-42` in the rule makes
`git fetch` fail whenever that branch doesn't exist, which is the case
before the first push and after the branch is deleted.

**Within a feature, nothing changes.** When the anchor repository also ships
code, its code working copy (`<ID>-code`) is a linked worktree of the
feature's anchor clone. The coordinator and that worker therefore share the
feature's branches.

**What else becomes per feature:**

- the stash, repository config and git hooks;
- Claude Code's saved approvals ("Yes, and don't ask again"), which it keeps
  at the repository's root;
- Copilot's saved directory approvals.

**Main checkouts become read-only for agents.** Feature sessions can read
their files but cannot run git commands there, because a main checkout
lists every branch you have fetched.

**Costs:**

- A clone doesn't get the main checkout's git hooks, local config or Git LFS
  objects. `fw start` copies the hooks and the `user.*` settings, and points
  LFS storage at the main checkout's. Any other repository-local setup, such
  as `pre-commit install`, runs again in each clone.
- Hard links need the clone on the same disk as the main checkout;
  otherwise git copies the objects.
- Feature branches no longer appear in your main checkout until you fetch
  them.

**Incoming changes.** Once another feature's PR merges, its changes are on
the default branch, and `git fetch` brings them in. `fw incoming` (part 4)
shows them.

**Features already in flight.** Features started before this change keep
their linked worktrees until they finish. For them, the guard also blocks
`git stash` and `git config` writes, because those are still shared.

### 2. The guard knows about other features

Today `worktree-guard` checks writes and repositories. It gains a picture of
the workspace, rebuilt from the filesystem on each call, so it covers a
feature started an hour ago without relaunching anything:

- **Other features** are the folders in `.feature/` except this one,
  `config` and `_archive`.
- **Their working copies** are every folder under a `<repo>/.worktrees/` in
  the workspace that is not one of this feature's.
- **Their branches** are `<prefix><ID>/*`. For features that keep today's
  names, they are `<prefix><ID>`, `-spec`, `-plan`, `-docs` and `--sub-*`;
  when two IDs could own a name, the longer ID owns it.

Each new rule denies with a reason and a hint.

**Files**

- **Another feature's state folder or working copies: no reads or writes.**
  This covers:
  - file tools: Claude Code's `Read`, `Grep`, `Glob`, `LSP`, `Edit`, `Write`
    and `NotebookEdit`; Copilot's `view`, `glob`, `grep`, `rg`, `create`,
    `edit` and `apply_patch`; Codex's `apply_patch`; Cursor's file reads;
  - shell commands: any path argument, redirection, or `cd`/`pushd` into
    them;
  - wildcards such as `<repo>/.worktrees/*/...` that could expand into them.
- **Recursive scans rooted above another feature: blocked.** This covers
  `grep -r`, `find`, `tree`, `ls -R`, `du` and archivers started from:
  - a main checkout or its `.worktrees/`;
  - the workspace;
  - `.feature/`.

  Allowed instead: `git grep` (tracked files only), and `rg` or `fd`
  unless asked to include hidden files (both skip hidden folders such as
  `.worktrees/` and `.feature/` by default).
- **Writes to `.feature/config` and `.feature/_archive/`: blocked.** Your
  human partner edits the shared config.
- **MCP tools: absolute paths in any string argument are checked**, on a
  best-effort basis.

**Git**

- **Git commands in a main checkout or in another feature's clone:
  blocked.** This covers `-C`, `--git-dir`, `--work-tree`, `GIT_DIR`,
  `GIT_WORK_TREE`, and a `cd` there first. A main checkout lists every
  branch you have fetched, and another feature's clone shows that feature's
  work.
- **Bringing other branches into the clone: blocked.** This covers:
  - `git fetch` or `git pull` with a branch or refspec outside the feature;
  - `git ls-remote`;
  - `gh pr checkout`;
  - changes to the clone's fetch settings (`git remote` changes and
    `git config remote.*` writes).
- **Pushing to a branch outside the feature: blocked**, in addition to
  today's rule for the default branch.

**fw**

- **Any command that names another feature's ID: blocked.** That includes
  `status`, `mail`, `dispatch`, `launch`, `lock`, `unlock`, `log-decision`,
  `finish`, `config` and `start`.
- **`fw list`: blocked in feature sessions**, because it shows every
  feature's status.
- **`fw where --dir` into another feature: blocked.**
- **`fw` defined as a shell function or alias is recognized too.**

**Sessions**

- **`SendMessage` to another feature's session: blocked.** The guard
  recognizes the target by a name that starts with that feature's ID and a
  hyphen. That is how the launcher names sessions, and how Claude Code's
  default names for unnamed sessions start (working-copy folder name, then a
  suffix).
- **`ListAgents` and `EnterWorktree`: blocked in feature sessions.**

**Tool names.**

- The PreToolUse matcher in `hooks.json` grows to include:
  - Claude Code: `Read|Grep|Glob|LSP|Monitor|PowerShell|SendMessage|ListAgents|EnterWorktree|mcp__.*`;
  - Copilot: `view|glob|grep|rg|write_bash|write_powershell`.
- `hooks-cursor.json` gains `preToolUse`, `beforeReadFile` and
  `beforeShellExecution` entries.
- The guard finds the session's identity from `CURSOR_PROJECT_DIR` or the
  payload's `workspace_roots`, because Cursor's CLI sends an empty `cwd`.
- Codex rejects an "ask" answer as unsupported, and a failed hook lets the
  call through. So the guard must deny there instead of asking. It
  recognizes Codex by the payload's `turn_id`; checking
  `CLAUDE_PLUGIN_ROOT` alone would not work, because Codex sets it too.

**Cost.** Reads are the most frequent tool calls, so the guard runs much
more often. The budget is under 50 ms per call with macOS's bash 3.2 and five
features in the workspace, and a test checks it. The guard keeps failing
open on errors.

### 3. The launcher configures each agent tool

**Claude Code.** `fw launch` writes `.feature/<ID>/sessions/<who>.json` and
starts the session with it, a name and the runtime variables. For A-1's
worker in `svc-a`, in a workspace at `/home/me/ws` where B-2 also runs:

```bash
cd /home/me/ws/svc-a/.worktrees/A-1 && \
  FC_SESSION_WORKTREE=/home/me/ws/svc-a/.worktrees/A-1 \
  FC_FEATURE_ID=A-1 FC_WHO=svc-a COMPOSE_PROJECT_NAME=fc-a-1-svc-a \
  claude --name A-1-svc-a --settings /home/me/ws/.feature/A-1/sessions/svc-a.json \
  --model ... --add-dir ... '<prompt>'
```

```json
{
  "permissions": {
    "deny": [
      "ListAgents",
      "EnterWorktree",
      "Read(//home/me/ws/.feature/B-2/**)",
      "Edit(//home/me/ws/.feature/B-2/**)",
      "Read(//home/me/ws/svc-a/.worktrees/B-2/**)",
      "Edit(//home/me/ws/svc-a/.worktrees/B-2/**)"
    ]
  },
  "crossSessionInbound": "refuse",
  "autoMemoryDirectory": "/home/me/ws/.feature/A-1/memory/svc-a"
}
```

The `//` prefix is how Claude Code writes an absolute path in a permission
rule.

- **Precedence.** `--settings` sits above user, project and local settings
  and below managed settings. Lists merge, so this adds deny rules without
  removing anything the engineer set.
- **When it is read.** Treat the file as fixed at launch: Claude Code's live
  reload covers user, project, local and managed settings, not
  `--settings`. That is why the guard, not this file, covers features
  started later.
- **Why have it anyway.** It is a second line of defense for when the guard
  fails open. It also covers what hooks do not see: `@file` mentions and
  the context an IDE shares.
- **Deny rules.** A `Read` deny also blocks Edit and Write on the same path,
  and the `Edit` deny adds NotebookEdit. A bare tool name such as
  `ListAgents` removes that tool from the session.
- **Messages.** `crossSessionInbound: refuse` drops messages that arrive from
  other sessions, including ones posted to the session's socket.
- **Memory.** `autoMemoryDirectory` keeps each feature's and participant's
  memory with the feature's state, so it is archived with it. Claude Code
  accepts this key from `--settings`.
- **Names.** `--name` gives every session a predictable name, `<ID>-<who>`.
- **Resume.** Claude Code does not restore `--settings` or `--add-dir` when
  a session resumes, so `fw launch` gains a `--resume` option that resumes
  the named session with the same flags.

**Codex.** The launcher adds three flags:

- `--no-daemon`, so each session has its own process and environment;
- `-c sandbox_workspace_write.network_access=true`, so the network is open;
- `--add-dir` for the session's own git directory (the clone's `.git`, and
  the code worktree's own git directory in the anchor), so commits work.

It no longer passes the main checkout's git directory. Today, that makes
every feature's worktree entries writable from any Codex session.

Decision 8 also points the manifest's `hooks` at `./hooks/hooks.json`, so the
guard, the Stop gate and the session-start context run in Codex. Each
engineer trusts the hooks once with `/hooks`. Our `hooks.json` already
matches Codex's hook schema: Codex ignores the `shell` field, and both tools
take `timeout` in seconds.

**Copilot CLI.** No new flags:

- The guard already runs as a plugin hook. It gains Copilot's read tools.
- Copilot asks before reading outside the session's directories. It saves
  those approvals per repository, so with one clone per feature they no
  longer carry over to another feature.
- Copilot Memory is per GitHub repository. Engineers who want it off can run
  `/memory off`; the plugin never edits user configuration.

**Cursor and Gemini CLI.** You start these by hand, so there is no launcher
layer:

- **Cursor** gets the guard through its hook events.
- **Gemini CLI**'s extension hooks would have to live in the same
  `hooks/hooks.json`, with different event names. The guard there is a
  follow-up (decision 10); until then, Gemini relies on the skills.

### 4. Conventions

**Incoming changes.** A new command, `fw incoming <ID> [--repo R]`, fetches
each of the feature's clones and reports, per repository:

- the commits on the default branch that the feature's branch doesn't have
  yet;
- the files those commits change that the feature also changed;
- a conflict preview of merging the default branch into the feature branch
  (`git merge-tree --write-tree`, git 2.38 or later).

Who runs it:

- **The coordinator**, during research and planning, after each merge step,
  and when a worker reports a ripple.
- **Workers**, before reporting complete and before merging the default
  branch.

Results go to the coordinator and your human partner. The command never
looks at other features' branches. In the research prompt, "Overlapping
work" becomes "Recent changes": the default branch's history for the files
the feature touches.

**Runtime names.**

- The launcher and the Stop gate export three variables: `FC_FEATURE_ID`,
  `FC_WHO` and `COMPOSE_PROJECT_NAME=fc-<id>-<who>` (lowercased).
- Compose gives the environment variable precedence over a compose file's
  `name:`, so features' stacks never merge into one project.
- Fixed host ports, `container_name`, external volumes and shared local
  databases can still collide. A repository can key them on
  `FC_FEATURE_ID`.

**Skills.**

- The bootstrap rule gains one line about the boundary.
- The session-start context states the boundary. It also warns when a
  session did not come from `fw launch`, because then there are no
  per-session settings and messages are shared.
- The worker "Never" list gains three items:
  - reading another feature's state or working copies;
  - messaging another feature's sessions;
  - fetching another feature's branches.
- Finishing: durable learnings from the feature's memory go into the
  repository's `CLAUDE.md` through the docs PR.
- `claude-code-tools.md` drops the `SendMessage` nudge. The mailbox stays
  the channel within a feature.
- The branch names change in `workspace-and-state.md`, the skills and the
  provider references.

## Coverage by agent tool

| Protection | Claude Code | Copilot CLI | Codex | Cursor | Gemini CLI |
|---|---|---|---|---|---|
| Other features' branches, stash and config | not in the feature's clones | same | same | same | same |
| Writes into other features' files | guard + deny rules | guard | sandbox (clone and state only); guard with decision 8 | guard | skills only |
| Reads of other features' files | guard + deny rules | guard, plus Copilot's own prompt | guard with decision 8 | guard | skills only |
| Fetching other features' branches; git in main checkouts | guard | guard | guard with decision 8 | guard | skills only |
| `fw` for other features | guard | guard | guard with decision 8 | guard | skills only |
| Messages between sessions | inbound refused; `ListAgents` removed; guard checks `SendMessage` | none known | separate processes (`--no-daemon`) | none known | none known |
| Memory | per feature (`autoMemoryDirectory`) | per GitHub repository; `/memory off` | off by default | not covered | not covered |
| Network | open | open | open (new flag) | open | open |
| Runtime names | launcher | launcher | launcher | your shell | your shell |

## What stays shared

- **The main checkout's object store**, which the clones borrow through hard
  links. They share objects, not branches. A deliberate `git cat-file` on a
  known hash could still read an object from another feature that the main
  checkout had fetched.
- **Machine-level resources:** the OS user, credentials (git, gh, cloud
  CLIs), the network and local services.
- **Session transcripts** under each tool's home folder:
  `~/.claude/projects/`, `~/.codex/sessions` and `~/.copilot/session-state/`.
  Any session that goes looking can read them. A later guard rule could
  deny the paths of other features' sessions.
- **Copilot's session store and Memory.**
- **The code host, tracker and chat.** Other features' PRs and work items
  are visible to anyone who looks. The skills point agents only at their own
  feature's PRs, and the guard blocks fetching other features' branches into
  a clone.
- **Programs that open files themselves**, such as scripts, compilers and
  test runners.
- **In Codex, `/tmp`**, which every Codex session can write.

## Decisions for your review

Each decision has a recommended default. You can reply "go with the
recommendations" or change any of them.

1. **One clone per feature and repository**, instead of linked worktrees of
   the main checkout:
   - *Recommended:* clones made with hard links, fetching the default
     branch's full history, the tags and the feature's own branches.
   - *Alternative:* keep linked worktrees. The guard then blocks git
     commands that name other features' branches, `git stash` and
     `git config` writes. But `git branch` and `git log --all` still list
     other features' branches and commits.
2. **Branch names under a folder per feature** (`feat/PAY-42/code`, `/spec`,
   `/plan`, `/docs`, `/sub-<slug>`), for new features:
   - *Recommended:* needed for a fetch rule that matches exactly one
     feature.
   - *Alternative:* keep today's names and fetch `feat/PAY-42*`, which also
     brings in the branches of any feature whose ID starts the same way
     (PAY-421).
3. **Other features' work reaches a feature only through the default
   branch.** No reads of their working copies or state, and no fetching of
   their branches; `fw incoming` shows what landed. *Recommended.*
4. **Claude Code messages:**
   - *Recommended:* refuse inbound messages in every feature session and
     remove `ListAgents`. The mailbox stays the channel within a feature,
     which ends the `SendMessage` nudge to read mail.
   - *Alternative:* keep inbound messages on and rely on the guard's check
     of `SendMessage` targets. That keeps nudges within a feature, but it
     depends on session names.
5. **Claude Code auto memory:**
   - *Recommended:* one directory per feature and participant, under the
     feature's state and archived with it. Durable learnings go into the
     repository's `CLAUDE.md` through the docs PR.
   - *Alternative:* turn auto memory off in feature sessions.
6. **Workers may read their own feature's other working copies**; writes
   stay blocked. *Recommended.*
7. **Archived features** (`.feature/_archive/`) are readable as history but
   never writable. *Recommended.*
8. **Codex:**
   - *Recommended:* turn the plugin's hooks on. The cost: the plugin leaves
     the public Codex plugin directory, and each engineer must trust the
     hooks once with `/hooks`. This goes together with the new flags for
     network, no shared server and the git directory.
   - *Alternative:* stay without hooks. The sandbox still blocks writes, but
     the read, git and `fw` rules do not apply in Codex.
9. **Strict read fence** (Claude Code's
   `permissions.blockReadsOutsideWorkingDirectories`): opt-in, not the
   default. It would likely also refuse reads of `/tmp`, of the plugin's
   own reference files and of other folders research uses. *Recommended.*
10. **Gemini CLI guard as a follow-up**, because of the shared hooks file.
    *Recommended.*

## Implementation plan

There is no feature flag: isolation is on by default, and `FC_GUARD=off`
stays the escape hatch for debugging. Each step ships with its tests.

1. **Clones** (`feature-workspace`):
   - `start` clones instead of running `git worktree add`: hard links,
     `origin`, fetch rules, branch names, hooks, `user.*` settings, LFS
     storage and `.worktreeinclude` files;
   - the anchor's code working copy becomes a linked worktree of the
     feature's anchor clone;
   - `finish` checks for unpushed or unmerged commits, then removes the
     clones;
   - every `fw` git operation uses the feature's clones, never a main
     checkout;
   - features already in flight keep their worktrees.
2. **Workspace model** (`fc-lib`): other features, their working copies,
   branches and session names, with a cache per call.
3. **Guard, files:** read and write checks, dispatch on tool names for
   Claude Code, Copilot, Codex and Cursor, and the matcher in
   `hooks/hooks.json`.
4. **Guard, shell:** path arguments, `cd`, wildcards and recursive scans.
5. **Guard, git:** main checkouts, other clones, fetch and push rules; stash
   and config rules for features in linked worktrees.
6. **Guard, fw and sessions:** the `fw` rules; `SendMessage`, `ListAgents`
   and `EnterWorktree`; deny instead of ask in Codex.
7. **Launcher** (`feature-workspace`):
   - Claude Code: the settings file, `--name` and `--resume`;
   - Codex: the new flags;
   - the runtime variables;
   - `start` creates `sessions/` and `memory/`.
8. **Stop gate:** the runtime variables for the gate command.
9. **Manifests:** `hooks` in `.codex-plugin/plugin.json`; the Cursor events
   in `hooks/hooks-cursor.json`.
10. **New command:** `fw incoming`.
11. **Skills and docs:**
    - skills: the bootstrap rule, coordinating, working-a-repo-slice,
      finishing, the research prompt, the per-tool references and the
      provider references (branch names);
    - `hooks/session-start`;
    - `workspace-and-state.md` and the README's "What is enforced";
    - `docs/architecture.md` (a new requirement, R31, and the parity table);
    - `docs/team-setup.md` (trusting hooks in Codex), `docs/README.codex.md`,
      and the release notes.
12. **Live checks** in each tool (see the test plan).

## Test plan

- **Clones.**
  - A clone lists only the default branch and its feature's branches, while
    the remote also has another feature's branch, a feature with a longer ID
    that starts the same way, and a release branch.
  - The clone has the default branch's full history.
  - `git fetch` works before the first push and after a feature branch is
    deleted.
  - The pack files are hard links.
  - A repository without a remote works end to end: `origin` is the main
    checkout, the feature pushes there, and your human partner merges.
  - `finish` refuses while commits are unpushed.
- **Two-feature fixture.** A-1 and B-2 share a repository, and B-2 starts
  after A-1 launches. The tests are table-driven:
  - every "Proposed" row above becomes a test;
  - each deny case has a nearby allow case: reading own state, reading
    `.feature/config` and `_archive`, `git log` and `git merge-tree` against
    the default branch, `git merge origin/<default>`, `rg` from a main
    checkout, `grep -r` in your own working copy, `fw status A-1`, and
    `SendMessage` to `A-1-coordinator`.
- **Payload shapes.** Every tool name, in each agent tool's format: Claude
  Code, Copilot (camelCase and PascalCase), Codex, and Cursor's events.
- **Launcher.**
  - The generated JSON parses.
  - The deny rules list exactly the other features.
  - The flags match each CLI and its version (`cli_has`).
- **Stop gate.** The runtime variables reach the gate command.
- **Lint and CI.** The bash 3.2 lint runs over the new code, and the macOS
  CI job passes.
- **Timing.** The guard's median stays under 50 ms with five features.
- **Live checks:**
  - **Claude Code:** `/status` lists the command-line settings, `ListAgents`
    is absent, a message from another feature's session is refused, and
    reads are denied.
  - **Codex:** hooks load after `/hooks` trust, a commit in a clone works,
    and `curl` works.
  - **Copilot:** `view` is denied.
  - **Cursor:** `beforeReadFile` is denied.

## Sources

**Checked for this design** (documentation fetched, or source read, on
2 November 2026, plus local git tests):

- **Claude Code** documentation:
  - [Settings files and precedence](https://code.claude.com/docs/en/settings):
    where `--settings` sits, lists merging, and local approvals in worktrees;
  - [Configure permissions](https://code.claude.com/docs/en/permissions):
    `//` absolute paths, what deny rules reach in Bash, Read deny blocking
    Edit and Write, and hook blocks winning over allow rules;
  - [How Claude remembers your project](https://code.claude.com/docs/en/memory):
    memory shared across worktrees, and `autoMemoryDirectory` from
    `--settings`;
  - [Message your other Claude Code sessions](https://code.claude.com/docs/en/cross-session-messaging):
    reach, defaults, `crossSessionInbound`, and the deny rules;
  - [Manage sessions](https://code.claude.com/docs/en/sessions):
    `-n`/`--name`, and flags that are not restored on resume;
  - [Tools reference](https://code.claude.com/docs/en/tools-reference):
    `ListAgents`, `SendMessage`, `EnterWorktree`, `Monitor`, and Grep and
    Glob being absent on macOS and Linux;
  - [Hooks reference](https://code.claude.com/docs/en/hooks): hooks inside
    subagents, and exit code 2;
  - [Choose a permission mode](https://code.claude.com/docs/en/permission-modes):
    `blockReadsOutsideWorkingDirectories`.
- **Codex** source on GitHub (`openai/codex`, main):
  - `core-plugins/src/manifest.rs` and `loader.rs`: manifest `hooks`, and
    skipping the default file;
  - `protocol/src/hooks.rs`: the hook schema;
  - `hooks/src/engine/output_parser.rs`: "ask" is unsupported;
  - `protocol/src/permissions.rs`: worktree git directories made read-only;
  - `tui/src/daemon_startup.rs`: the shared server.
- **Codex** documentation:
  [Build plugins](https://developers.openai.com/codex/plugins/build?install-scope=global)
  (hook discovery and trust).
- **Git** (tested with git 2.43):
  - linked worktrees share the stash, config and branches;
  - a clone made from the main checkout with hard links, fetching `main` and
    `feat/<ID>/*`, lists only those, with full history;
  - `git fetch` fails when a branch named exactly in a fetch rule is missing;
  - a clone can live inside the main checkout's ignored `.worktrees/`;
  - `merge-tree --write-tree` previews conflicts.
- **The guard's current behavior:** the table above, from a probe against
  this repository's `tests/lib.sh` workspace.

**From the research notes, not re-checked:**

- **Copilot CLI:** hook tool names and payloads, path permissions, the session
  store and Memory. Source: docs.github.com.
- **Codex:** network and sandbox details.
- **Cursor:** hook events. **Gemini CLI:** hook packaging.
- **Docker Compose:** project-name precedence.
