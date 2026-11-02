# Running Several Features Side by Side

**Status: design for review. Nothing in this document is implemented yet.**

An engineer usually has several features in flight, each with its own agent
team: a coordinator session and one worker session per repository. The teams
share one machine, one workspace and often the same repositories. This
document describes how the plugin keeps those teams apart, what it found
shared today, and the decisions that need your review before implementation.

## Goal

Each feature's team works as if it were alone on the machine, with two
deliberate exceptions:

- **Git history stays visible.** Every feature can fetch, log, diff and
  preview merges against any branch, including other features' in-flight
  branches. Linked worktrees of a repository share its refs, so a commit made
  by another feature's worker is visible to yours as soon as it is made,
  before anyone pushes. This is how a feature sees incoming changes that may
  break it or change its direction.
- **The network stays open.** No agent tool runs with network restrictions:
  research, package installs, code hosts, trackers and local services keep
  working.

"Kept apart" means two things. Both are about accidents, not a hostile agent:

1. **No corruption.** A team never writes into another feature's worktrees,
   state folder, branches or sessions, and never changes repository state
   that every feature shares (the stash, repository config, the worktree
   list).
2. **No status leaks.** A team never reads another feature's private state:
   its `.feature/<ID>/` folder (briefs, mail, decision log, research, proof),
   the uncommitted contents of its worktrees, or its sessions' messages and
   memory.

Out of scope: OS sandboxes, containers or VMs (option D), network isolation,
separate credentials per feature, CPU and memory limits, and an agent set on
getting around the rules (for example a script that opens files itself).
Like the existing guard, this is a guardrail against mistakes, not a
security boundary.

## Territory

For a session of feature F:

| Area | Access |
|---|---|
| This session's worktree | read and write |
| F's other worktrees | read (writes blocked, as today) |
| F's state, `.feature/F/` | read and write |
| Main checkouts, outside their `.worktrees/` folder | read (writes blocked, as today) |
| `.feature/config`, `.feature/_archive/` | read |
| Repository state every worktree shares: branches, tags, stash, config, remotes, worktree list | read; change only F's own branches |
| Another feature's state folder, worktrees, sessions and `fw` commands | none |
| Another feature's branches | read through git (log, diff, show, merge-tree); never written; taken into F only with your human partner's yes |
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
| Push to or delete B-2's branch | allowed | blocked |
| Merge, rebase onto, cherry-pick from or reset to B-2's branch | allowed | asks your human partner |
| `git stash pop` | allowed | blocked |
| `git config user.email ...` | allowed | blocked |
| `git worktree remove` on B-2's worktree | allowed | blocked |
| `SendMessage` to B-2's coordinator, `ListAgents`, `EnterWorktree` into B-2's worktree | not seen by the guard | blocked |
| `git log`, `git diff`, `git merge-tree` against B-2's branch | allowed | allowed |

The stash and config rows are real cross-feature corruption, not just
theory. In a test repository, a stash made in B-2's worktree appeared in
A-1's `git stash list` as "WIP on" B-2's branch. Running `git stash pop` in
A-1 then applied B-2's uncommitted change to A-1's worktree. A `git config`
run in A-1 also changed the value B-2 sees.

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

The design has three layers:

1. **The guard.** It works in every session that starts inside a feature
   worktree, however the session was launched, and it sees features created
   after the session started.
2. **The launcher.** It adds per-session settings in each agent tool.
3. **Conventions.** The skills and the runtime names.

### 1. The guard knows about other features

Today `worktree-guard` checks writes and repositories. It gains a picture of
the workspace, rebuilt from the filesystem on each call, so it covers a
feature started an hour ago without relaunching anything:

- **Other features** are the folders in `.feature/` except this one,
  `config` and `_archive`.
- **Their worktrees** are every folder under a `<repo>/.worktrees/` in the
  workspace that is not one of this feature's.
- **Their branches** are `<prefix><ID>`, `<prefix><ID>-spec`, `-plan`,
  `-docs` and `<prefix><ID>--sub-*`. When two IDs could own a branch name,
  the longer ID owns it.

Each new rule denies with a reason and a hint.

**Files**

- **Another feature's state folder or worktrees: no reads or writes.** This
  covers:
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

**Git** (the repository state every worktree shares)

- **`-C`, `--git-dir`, `--work-tree`, `GIT_DIR` or `GIT_WORK_TREE` pointing
  into another feature's worktree: blocked.** That is how `git status` or
  `git diff` would show its uncommitted work. Reading another feature's
  branch from your own worktree is fine.
- **Pushing to, deleting, renaming, force-moving or `update-ref` on another
  feature's branch: blocked.**
- **Merging, rebasing onto, cherry-picking from, resetting to or pulling
  another feature's branch:** Claude Code asks your human partner; other
  tools deny with the reason. Merging the default branch stays allowed.
- **`git stash`, in every form: blocked.** The hint is to commit work in
  progress on your own branch instead.
- **`git config` writes and `git remote add|set-url|rename|remove`:
  blocked.** Your human partner changes shared config.
- **`git worktree remove|move|lock|unlock` on another feature's worktree:
  blocked.**

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
  default names for unnamed sessions start (worktree folder name, then a
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

### 2. The launcher configures each agent tool

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
- **Memory.** `autoMemoryDirectory` gives each feature and participant its
  own memory. Claude Code accepts this key from `--settings`.
- **Names.** `--name` gives every session a predictable name, `<ID>-<who>`.
- **Resume.** Claude Code does not restore `--settings` or `--add-dir` when
  a session resumes, so `fw launch` gains a `--resume` option that resumes
  the named session with the same flags.

**Codex.** The launcher adds three flags:

- `--no-daemon`, so each session has its own process and environment;
- `-c sandbox_workspace_write.network_access=true`, so the network is open;
- `--add-dir` for the worktree's own git directory, so commits work.

Decision 9 also points the manifest's `hooks` at `./hooks/hooks.json`, so the
guard, the Stop gate and the session-start context run in Codex. Each
engineer trusts the hooks once with `/hooks`. Our `hooks.json` already
matches Codex's hook schema: Codex ignores the `shell` field, and both tools
take `timeout` in seconds.

The sandbox keeps doing what it does today: writes go only to the worktree,
the feature's state and the repository's git directory. That git directory
includes other features' entries under `worktrees/`. The guard's git rules
cover git commands there, and Codex's beta permission profiles could narrow
the directory later.

**Copilot CLI.** No new flags:

- The guard already runs as a plugin hook. It gains Copilot's read tools.
- Copilot asks before reading outside the session's directories, but it
  saves those approvals per repository. The guard is what stops them from
  carrying over to another feature.
- Copilot Memory is per repository. Engineers who want it off can run
  `/memory off`; the plugin never edits user configuration.

**Cursor and Gemini CLI.** You start these by hand, so there is no launcher
layer:

- **Cursor** gets the guard through its hook events.
- **Gemini CLI**'s extension hooks would have to live in the same
  `hooks/hooks.json`, with different event names. The guard there is a
  follow-up (decision 11); until then, Gemini relies on the skills.

### 3. Conventions

**Seeing other features through git.** A new command,
`fw overlaps <ID> [--repo R]`, reports on other in-flight feature branches:

- **Which branches.** In each participating repository, it lists the other
  feature branches visible locally and on the remote. It finds them by
  branch prefix, using git only and never other features' state folders.
- **What it shows for each branch:**
  - its commits ahead of the default branch;
  - the files it shares with this feature's branch;
  - a conflict preview from `git merge-tree --write-tree` (git 2.38 or
    later).
- **Who runs it:**
  - The coordinator runs it during research (it feeds "Overlapping work" in
    the research notes and the plan's risks), before each merge step, and
    when a worker reports a ripple.
  - Workers run it before reporting complete and after merging the default
    branch.
- **Where overlaps go.** To your human partner, who decides whether features
  should coordinate. The agents never contact each other.

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
  per-session settings and memory and messages are shared.
- The worker "Never" list gains three items:
  - reading another feature's state or worktrees;
  - messaging another feature's sessions;
  - taking another feature's branch without your human partner.
- Finishing: durable learnings from the feature's memory go into the
  repository's `CLAUDE.md` through the docs PR.
- `claude-code-tools.md` drops the `SendMessage` nudge. The mailbox stays
  the channel within a feature.

## Coverage by agent tool

| Protection | Claude Code | Copilot CLI | Codex | Cursor | Gemini CLI |
|---|---|---|---|---|---|
| Writes into other features' files | guard + deny rules | guard | sandbox; guard with decision 9 | guard | skills only |
| Reads of other features' files | guard + deny rules | guard, plus Copilot's own prompt | guard with decision 9 | guard | skills only |
| Shared git state, other features' branches | guard | guard | guard with decision 9 | guard | skills only |
| `fw` for other features | guard | guard | guard with decision 9 | guard | skills only |
| Messages between sessions | inbound refused; `ListAgents` removed; guard checks `SendMessage` | none known | separate processes (`--no-daemon`) | none known | none known |
| Memory | per feature (`autoMemoryDirectory`) | per repository; `/memory off` | off by default | not covered | not covered |
| Network | open | open | open (new flag) | open | open |
| Runtime names | launcher | launcher | launcher | your shell | your shell |

## What stays shared

- **Git objects and refs**, by design, so that history stays visible.
- **Machine-level resources:** the OS user, credentials (git, gh, cloud
  CLIs), the network and local services.
- **Claude Code's "don't ask again" approvals**, per repository. The guard
  still blocks.
- **Session transcripts** under each tool's home folder:
  `~/.claude/projects/`, `~/.codex/sessions` and `~/.copilot/session-state/`.
  Any session that goes looking can read them. A later guard rule could
  deny the paths of other features' sessions.
- **Copilot's session store and Memory.**
- **In Codex, the repository's git directory and `/tmp`**, which every Codex
  session can write.
- **Programs that open files themselves**, such as scripts, compilers and
  test runners.
- **The code host, tracker and chat.** Other features' PRs and work items
  are visible to everyone, as they are to the team.

## Decisions for your review

Each decision has a recommended default. You can reply "go with the
recommendations" or change any of them.

1. **No direct reads of another feature's worktrees.** Its commits stay
   visible through git as soon as they are made. *Recommended.*
2. **Taking another feature's unmerged work into yours** (merge, rebase
   onto, cherry-pick, reset to, pull): Claude Code asks your human partner,
   and the other tools deny with the reason. Previews (`git diff`,
   `git merge-tree`) need no approval. *Recommended.*
3. **Claude Code messages:**
   - *Recommended:* refuse inbound messages in every feature session and
     remove `ListAgents`. The mailbox stays the channel within a feature,
     which ends the `SendMessage` nudge to read mail.
   - *Alternative:* keep inbound messages on and rely on the guard's check
     of `SendMessage` targets. That keeps nudges within a feature, but it
     depends on session names.
4. **Claude Code auto memory:**
   - *Recommended:* one directory per feature and participant, under the
     feature's state and archived with it. Durable learnings go into the
     repository's `CLAUDE.md` through the docs PR.
   - *Alternatives:* turn auto memory off in feature sessions, or leave it
     shared.
5. **`git stash` blocked in feature sessions**, because a repository has one
   stash for all its worktrees. Commit work in progress on your own branch
   instead. *Recommended.*
6. **Shared repository config and remotes** (`git config` writes,
   `git remote add|set-url|rename|remove`) blocked; your human partner
   changes them. *Recommended.*
7. **Workers may read their own feature's other worktrees**; writes stay
   blocked. *Recommended.*
8. **Archived features** (`.feature/_archive/`) are readable as history but
   never writable. *Recommended.*
9. **Codex:**
   - *Recommended:* turn the plugin's hooks on. The cost: the plugin leaves
     the public Codex plugin directory, and each engineer must trust the
     hooks once with `/hooks`. This goes together with the new flags for
     network, no shared server and the git directory.
   - *Alternative:* stay without hooks. The sandbox still blocks writes, but
     the read, git and `fw` rules do not apply in Codex.
10. **Strict read fence** (Claude Code's
    `permissions.blockReadsOutsideWorkingDirectories`): opt-in, not the
    default. It would likely also refuse reads of `/tmp`, of the plugin's
    own reference files and of other folders research uses. *Recommended.*
11. **Gemini CLI guard as a follow-up**, because of the shared hooks file.
    *Recommended.*
12. **Add `fw overlaps`.** *Recommended.*

## Implementation plan

There is no feature flag: isolation is on by default, and `FC_GUARD=off`
stays the escape hatch for debugging. Each step ships with its tests.

1. **Workspace model** (`fc-lib`): other features, their worktrees, branches
   and session names, with a cache per call.
2. **Guard, files:** read and write checks, dispatch on tool names for
   Claude Code, Copilot, Codex and Cursor, and the matcher in
   `hooks/hooks.json`.
3. **Guard, shell:** path arguments, `cd`, wildcards and recursive scans.
4. **Guard, git:** the git rules above.
5. **Guard, fw and sessions:** the `fw` rules; `SendMessage`, `ListAgents`
   and `EnterWorktree`; deny instead of ask in Codex.
6. **Launcher** (`feature-workspace`):
   - Claude Code: the settings file, `--name` and `--resume`;
   - Codex: the new flags;
   - the runtime variables;
   - `start` creates `sessions/` and `memory/`.
7. **Stop gate:** the runtime variables for the gate command.
8. **Manifests:** `hooks` in `.codex-plugin/plugin.json`; the Cursor events
   in `hooks/hooks-cursor.json`.
9. **New command:** `fw overlaps`.
10. **Skills and docs:**
    - skills: the bootstrap rule, coordinating, working-a-repo-slice,
      finishing, and the per-tool references;
    - `hooks/session-start`;
    - `workspace-and-state.md` and the README's "What is enforced";
    - `docs/architecture.md` (a new requirement, R31, and the parity table);
    - `docs/team-setup.md` (trusting hooks in Codex), `docs/README.codex.md`,
      and the release notes.
11. **Live checks** in each tool (see the test plan).

## Test plan

- **Two-feature fixture.** A-1 and B-2 share a repository, and B-2 starts
  after A-1 launches. The tests are table-driven:
  - every "Proposed" row above becomes a deny case;
  - each deny case has a nearby allow case: reading own state, reading
    `.feature/config` and `_archive`, `git log`, `git diff` and
    `git merge-tree` against B-2, `git merge origin/<default>`, `rg` from a
    main checkout, `grep -r` in your own worktree, `fw status A-1`, and
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
  - **Codex:** hooks load after `/hooks` trust, a commit in a worktree
    works, and `curl` works.
  - **Copilot:** `view` is denied.
  - **Cursor:** `beforeReadFile` is denied.

## Sources

**Checked for this design** (documentation fetched, or source read, on
2 November 2026, plus a local git test):

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
- **Git:** a shared stash, config and refs across linked worktrees, and
  `merge-tree`, tested with git 2.43.
- **The guard's current behavior:** the table above, from a probe against
  this repository's `tests/lib.sh` workspace.

**From the research notes, not re-checked:**

- **Copilot CLI:** hook tool names and payloads, path permissions, the session
  store and Memory. Source: docs.github.com.
- **Codex:** network and sandbox details.
- **Cursor:** hook events. **Gemini CLI:** hook packaging.
- **Docker Compose:** project-name precedence.
