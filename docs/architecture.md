# Architecture

This plugin implements the revised design from the October 2026 research
review of the original multi-repo coordinator proposal. This page records
the decisions, why they were made, what is enforced versus conventional, and
what still needs piloting.

## The core decision

**Split by context boundary; one full session per repository worktree.**

The original design had a coordinator session that dispatched background
subagents into sibling repositories added with `--add-dir`, kept in line by
their prompts. The research found that this cannot be made safe:

- Subagents start in the main conversation's working directory, and Claude
  Code's `isolation: worktree` and worktree checks cover only the repository
  the session was launched from.
- `--add-dir` grants file access, not configuration: the sibling repo's
  hooks and settings never load, so its committed protections never fire.
- `AskUserQuestion` is removed from every subagent, so a worker could only
  guess or relay questions through the coordinator.
- Copilot CLI loads hooks from the current working directory, and `/fleet`
  subagents share the launching session.

Anthropic's guidance ("Building agents: when to fold subagents into your
main agent loop", Oct 2026) says to divide by context, not by problem type,
and to keep subagents for independent work with clean interfaces. A service
repository with locked contracts is that case; a "scout", "doc fetcher" or
"planner" subagent is not, so those became skills and built-in read-only
exploration inside each loop.

So: one coordinator session in the anchor worktree (reads everything, edits
only the anchor), one worker session per repo worktree (its own cwd, hooks,
instructions, and the ability to ask the engineer), and file-based handoff -
the merged plan, the contract copies and a mailbox - instead of summaries.

## Components

| Component | Role |
|---|---|
| `skills/` | 12 harness-agnostic skills; `using-feature-coordinator` is the bootstrap |
| `skills/coordinating-multi-repo-features/scripts/feature-workspace` | Worktrees, state, contract lock, mailbox, decision log, status, launch commands, cleanup |
| `.../scripts/fc-lib` | Shared helpers (paths, records, config, JSON, code-host detection) |
| `hooks/session-start` | Bootstrap + "who am I in which feature" context + team stack |
| `hooks/worktree-guard` | PreToolUse: confine edits and shell writes to the session's worktree; block force pushes, default-branch pushes, merges, approvals, unlocks |
| `hooks/feature-gate` | Stop: contract check + gate command for workers, once per worktree state |
| `references/providers/` | One reference per tracker / code host / chat, behind a shared action vocabulary |
| `references/<harness>-tools.md` | Per-harness mapping of the actions the skills name |

The scripts have no runtime dependencies beyond `git` and `bash` 3.2 (the
macOS default), so the same files run on macOS, Linux and Git for Windows.

## Lifecycle and gates

| Phase | Output | Gate (human) |
|---|---|---|
| Start | worktrees, `.feature/<ID>/`, work item in progress | - |
| Spec | Spec PR in the anchor repo | approve + merge |
| Plan | Plan PR with PR matrix, acceptance tests, rollout, contract copies | code owners approve, engineer merges; `lock` |
| Code wave | one draft PR per repo, opened as soon as its contracts are applied | comments on the drafts at any time |
| Review | triaged threads, sub-PRs | approvals per commit, once a PR is ready |
| Ready | the coordinator marks the current merge step's complete PRs ready | - |
| Merge | plan order, step by step; any flags where the plan says they start | engineer merges each |
| Rollout | flag changes in plan order, if the plan uses flags; otherwise the merges | engineer makes each change |
| Finish | docs PR (decisions, proof index), cleanup | merge |

Inside a phase the agents run autonomously within the budget the engineer
set (`/goal` in Claude Code, Autopilot caps in Copilot). An opt-in milestone
runner lets the coordinator advance through the PR matrix when the
deterministic gates hold - it still never merges.

## Drafts and merge order

Every PR opens as a draft and stays one until its merge step in the plan
comes. Drafts let reviewers comment while the work is in progress, and the
worker triages those comments as they arrive, so review starts early instead
of piling up at the end. Ready (Azure DevOps: active) means "this is next to
merge": the coordinator marks a PR ready only when every PR in the earlier
steps has merged and the worker has reported it complete. PRs that share a
step can be ready together. A ready PR that needs a large change goes back
to draft. Workers never mark their own feature PR ready; they may mark their
stacked sub-PRs ready, since those merge into the feature branch.

This matches how the hosts treat drafts: GitHub requests code owners and
Azure DevOps adds required reviewers and opens voting only when a draft
becomes ready, so approvals are asked for in merge order. Who marks a PR
ready is a skill rule; `fw status` shows each PR's draft or ready state on
GitHub, Azure DevOps, GitLab and review packets.

## Contract lock design

The research left two options: commit contract changes on each owning
repo's plan branch, or quote them with hashes in the plan. This plugin keeps
**copies in the anchor repo** under `<docs_dir>/<ID>/contracts/<repo>/<path>`
and locks their **git blob ids** when the plan PR merges:

- one PR (the plan) carries every contract, so one review sees them all;
- the lock is exactly the merged bytes, checkable with `git hash-object`;
- each worker's first commit applies its contracts (`apply-contract`), so
  its PR shows the contract change next to the code;
- drift is caught twice: the guard blocks edits to locked paths, the Stop
  gate compares blob ids.

Amendments go through a new plan PR; only the engineer can `unlock` a path
in the meantime.

## Configurable stack, any git host

The skills speak in actions (T1-T5 tracker, H1-H9 code host, C1-C2 chat).
`.feature-coordinator.conf` in the anchor repo picks the tracker and chat;
each engineer can override locally.

The code host is a property of **each repository**, not of the team, because
real features cross hosting boundaries: a service on GitHub, a ledger on an
on-prem Azure DevOps Server, a pricing engine in Gerrit, a prototype that
lives only on the engineer's disk. Each repo's host comes from
`code_host.<repo>`, the repo's own config, a team-wide value, or detection
from its `origin` URL, and a repo with no remote is `local`. The provider
reference for each host implements the same action codes; for repos without
a pull-request system (`local`, `other`), "open a PR" becomes a review packet
the engineer reads locally, and the engineer merges in the main checkout.

The host matters for three things only: which reference the agent reads,
how `fw status` reports the PR column (`gh`, `az repos`, `glab`, or git
plus the review packet), and how `fw finish` decides a branch is merged
(ancestry, patch equivalence via `git cherry` for rebase and cherry-pick
submits, then the host's merged state for squash merges). Everything else -
worktrees, contract lock, mailbox, gates, the guard's confinement and push
rules - is plain git and works the same everywhere. The guard also knows
each host's merge and approve commands (CLI and common REST forms).

Repositories must be git, because worktrees are. TFVC, Subversion, Perforce
and Mercurial repos can join through git bridges.

## Requirements traceability

R1-R25 are the requirements extracted from the original design discussion;
R26-R29 are later steers: technologies must be configurable, the plugin runs
locally across repos on any mix of git hosts, PRs stay drafts until their
turn in the merge order, and the plan decides whether to use feature flags.

| R | Requirement (short) | Satisfied by | Enforcement |
|---|---|---|---|
| R1 | Local-first; no cloud agents by default | Local sessions; cloud reviewers, sync, memory, routines opt-in only | Convention (skills); org policy for Copilot sync |
| R2 | Agents act as the engineer | Engineer's own git, CLI logins and MCP connections | Inherent |
| R3 | Central, versioned distribution | Plugin marketplace per ecosystem; repo `enabledPlugins`; managed force-enable | Deterministic (managed settings) |
| R4 | Humans gate phases and merge | Spec/plan/merge/rollout gates; merge commands blocked | Guard hook + branch protection |
| R5 | One owning engineer per feature | One workspace, one coordinator, sessions under one identity | Convention |
| R6 | Ticket status and links | Tracker actions T1-T5 per provider | Convention (skills) |
| R7, R8 | Spec, plan, code, docs and proof as PRs | Spec PR, Plan PR, per-repo PRs, docs PR with proof index | Skills + PR template |
| R9 | Normal code ownership and review | CODEOWNERS / path reviewers per host (H8) | Code host |
| R10 | Correlated worktrees per feature | `start` creates `<repo>/.worktrees/<ID>` on `<prefix><ID>` | Script |
| R11 | Parallel implementation and triage | `dispatch` starts every worker; each triages its own PR | Script + skills |
| R12-R14 | Triage review feedback, sub-PRs | triaging-pr-feedback buckets; sub-PR flow (H6); fix-all commands banned | Skill; guard blocks merge/approve |
| R15 | Decision block on every push | recording-decisions, PR template, decision log | Skill + template; optional CI check (team-setup) for determinism |
| R16 | Spec co-design at maximum effort | writing-unified-specs: max effort, plan mode | Skill |
| R17 | Ask, don't guess | Full sessions keep the ask tool; Tier 3 list; `protected_paths` | Skill + guard (`ask` in Claude Code) |
| R18, R19 | Local by default; team only on request | briefing (local), asking-the-team (approved text only) | Skill |
| R20 | See and steer each session | One terminal/tmux window/background session per repo; `status`; mailbox | Script |
| R21 | Model routing by role | `coordinator_model`, `worker_model`, `model.<repo>`, `effort` | Config + launcher |
| R22 | Verification and proof | verifying-with-proof; Stop gate | Hook (deterministic) + skill |
| R23 | Follow current agent best practice | Fold by context, progressive disclosure via skills, convergence rules | Architecture |
| R24 | Claude Code and Copilot parity | Same skills, hooks and script; file mailbox where messaging is missing | Partial (see below) |
| R25 | Easy install and version checks | Marketplaces, `bump-version.sh --check`, `claude plugin validate` | Script |
| R26 | Configurable tracker, code host, chat, conventions | `.feature-coordinator.conf`, provider references | Config + script |
| R27 | Local-first, with repos on any mix of git hosts, including custom servers and local-only repos | Per-repo code host (detection + `code_host.<repo>`), references for GitHub, Azure DevOps (Services/Server), GitLab, Bitbucket, Gerrit, Gitea, and a review-packet flow for repos without pull requests | Config + script; guard rules per host |
| R28 | PRs open as drafts so people can comment early and agents answer; only the PRs next in the merge order are ready (active) | Draft PR at the first push (H1), comment triage on drafts, coordinator marks the current merge step ready (H7) and returns reworked PRs to draft; draft state in `fw status` | Skills + host draft semantics; status in script |
| R29 | Whether to use feature flags, and whether each starts on or off, is decided in the implementation plan | Plan's "Feature Flags and Rollout" section (yes/no, starting state, order, rollback; or a rollout by merge step); finishing follows it | Skills + plan template |

## Parity

| Capability | Claude Code | Copilot CLI | Codex | Cursor | Gemini CLI |
|---|---|---|---|---|---|
| Skills | yes | yes | yes | yes | yes |
| Session-start context | yes | yes | no (hooks suppressed) | yes | via GEMINI.md (bootstrap only) |
| Worktree guard | yes | yes | sandbox instead | no | no |
| Stop gate | yes | yes (30 s default timeout) | worker runs checks | worker runs checks | worker runs checks |
| Launch commands | yes | yes | yes | manual | manual |
| Ask the engineer | AskUserQuestion | ask_user | in chat | in chat | ask_user |
| Cross-session messaging | mailbox (+ SendMessage nudge) | mailbox | mailbox | mailbox | mailbox |

## Verified facts this design depends on

- Claude Code: `--add-dir`, `--model`, `--effort`, `--permission-mode`,
  `--plugin-dir`, `--worktree` present in 2.1.316 `--help`;
  `CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (2.1.257+); plugin
  `hooks/hooks.json` with `${CLAUDE_PLUGIN_ROOT}`; PreToolUse exit 2 blocks
  with stderr as the reason; Stop hooks block with `{"decision":"block"}`.
- Copilot CLI: reads `.claude-plugin/plugin.json` and `hooks/hooks.json`;
  `sessionStart` consumes `additionalContext`; `preToolUse` denies on
  non-zero exit; timeouts fail open; `COPILOT_CLI=1` in the hook
  environment.
- Codex: `.codex-plugin/plugin.json` with `skills` and `hooks: {}`;
  `.agents/plugins/marketplace.json`; `--sandbox workspace-write`.
- Live test (Claude Code 2.1.316 with `--plugin-dir`): the session-start
  context reached the model (it named its feature, role, tracker, chat and
  first skill); the guard blocked a Write into a sibling worktree (exit 2)
  and allowed one in the session's own worktree; the Stop gate blocked the
  first stop on a failing gate and let the second stop on the same state
  through. The same test showed `hooks/run-hook.cmd` must keep its
  executable bit.
- CI runs the whole suite on Linux (bash 5, gawk) and on macOS with the
  stock `/bin/bash` 3.2 and one-true-awk 20200816; the JSON parser is also
  tested locally under mawk and busybox awk.
- Session-start output shapes (one field only - Claude Code reads both
  `additional_context` and `hookSpecificOutput` without de-duplicating)
  follow superpowers 7.0.1.

## Remaining risks and pilot checklist

- Copilot CLI's PascalCase compatibility payloads: confirm the PreToolUse
  matcher matches Copilot's tool names in your version (the guard also
  accepts Copilot's native `toolName`/`toolArgs` payload).
- Copilot hook timeout (30 s default) cuts off slow gate commands.
- Claude Code background sessions (`--bg`) started in a manual worktree: check
  they stay there.
- Cross-session messaging, agent view, advisor: research preview or
  experimental; the plugin does not depend on them.
- The guard's shell analysis is heuristic: it catches common write forms,
  not every program that can write a file.
- Run a small end-to-end evaluation (about ten real features) against the
  old process before rolling out widely, as Anthropic recommends.
