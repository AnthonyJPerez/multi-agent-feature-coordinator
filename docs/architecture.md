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
| Code wave | one PR per repo | per-PR review |
| Review | triaged threads, sub-PRs | approvals per commit |
| Merge | plan order, flags off | engineer merges each |
| Rollout | flags in plan order | engineer flips each |
| Finish | docs PR (decisions, proof index), cleanup | merge |

Inside a phase the agents run autonomously within the budget the engineer
set (`/goal` in Claude Code, Autopilot caps in Copilot). An opt-in milestone
runner lets the coordinator advance through the PR matrix when the
deterministic gates hold - it still never merges.

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

## Configurable stack

The skills speak in actions (T1-T5 tracker, H1-H9 code host, C1-C2 chat).
`.feature-coordinator.conf` in the anchor repo picks the providers; each
engineer can override locally; the code host is detected per repo from its
`origin` URL, so one feature can span GitHub and Azure Repos. The script
uses the configured host for status and merge checks (`gh`, `az repos`,
`glab`); the guard knows every supported host's merge and approve commands.

## Requirements traceability

R1-R25 are the requirements extracted from the original design discussion;
R26 is the later steer that technologies must be configurable.

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
| R26 | Configurable tracker, code host, chat, conventions | `.feature-coordinator.conf`, provider references, per-repo host detection | Config + script |

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
