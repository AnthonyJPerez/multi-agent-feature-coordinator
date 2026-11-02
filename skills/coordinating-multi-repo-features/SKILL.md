---
name: coordinating-multi-repo-features
description: Use when a feature, ticket or change spans more than one repository or service, when your human partner asks to start, resume or check on a multi-repo feature, or when this session is the coordinator in a feature's anchor worktree
---

# Coordinating Multi-Repo Features

## Overview

One feature, several repositories, one engineer who owns all of it. You are
the coordinator: you hold the whole picture, your human partner makes the
calls, and one worker session per repository does the implementation.

**Core principle:** split work by context boundary - one session per
repository worktree - and hand off through committed files, never through
summaries. A worker that reads the merged plan itself cannot be misled by a
paraphrase of it.

**Announce at start:** "I'm using the coordinating-multi-repo-features skill
to run this feature."

## The Shape

```
<workspace>/                       not a repository
  anchor-repo/.worktrees/<ID>/     coordinator: spec, plan, contracts, docs
  service-a/.worktrees/<ID>/       worker a: its slice, its PR
  service-b/.worktrees/<ID>/       worker b
  .feature/<ID>/                   local state: lock, mailbox, briefs, proof
```

- The **anchor repo** holds the feature's documents under
  `<docs_dir>/<ID>/` (default `docs/features/<ID>/`): `spec.md`, `plan.md`
  and `contracts/<repo>/<path>`. Pick the repo that owns the main API or the
  team's platform docs; ask your human partner if unsure.
- You read the other worktrees (they are added to your session); you edit
  only the anchor worktree and `.feature/<ID>/`.
- Details: `references/workspace-and-state.md`.

## Why Not Subagents for the Repos

Repo workers are full sessions, not subagents, because only a session started
inside a repo's worktree gets that repo's instructions, rules and hooks, its
own working directory for git and the code host CLI, and the ability to ask
your human partner a question. Subagents start in your directory and cannot
ask. Agent teams and fan-out commands share your working directory too. Use
subagents for read-only research and fresh-context review only.

## The Lifecycle

Your human partner gates every phase. Inside a phase, work autonomously
within the budget they set.

### 1. Start

1. Agree on the feature ID (use the work item key: `PAY-42`, `ENG-123`,
   `4711`), the anchor repo and the participating repos.
2. Create the worktrees and state:
   ```bash
   fw start <ID> --anchor <anchor> --repo <repo-a> --repo <repo-b>
   ```
   Re-run with more `--repo` flags to add repos later. Add
   `--gate <repo>=<command>` for a repo whose gate is not in the team config.
3. Check the team stack: `fw config <ID>` lists the tracker, the chat and
   each repo's code host (repos may live on different hosts, or only on this
   machine). If something is wrong, stop - your human partner fixes
   `.feature-coordinator.conf` in the anchor repo (or
   `<workspace>/.feature/config` for personal overrides; `code_host.<repo>`
   for a repo on a custom domain) and you run `fw config <ID> --refresh`,
   which also re-detects each repo's host.
4. If a tracker is configured, read the work item and mark it in progress,
   assigned to your human partner (provider reference: T1, T2).
5. Your human partner opens this coordinator session with
   `fw launch <ID> coordinator` if it is not already running there.

### 2. Research every repository

The spec and the plan are only as good as what you know about each
repository today, and one context holding every repository sees each of them
less clearly. Research each one in its own fresh context:

1. Dispatch one read-only research subagent per participating repository, in
   parallel, with `research-prompt.md` (this skill's folder). Each reads its
   repository's own instructions first and writes a note to
   `.feature/<ID>/research/<repo>.md`: where the feature lands, the
   interfaces the repository exposes and consumes, data, tests and gate,
   owners, flags and rollout, risks and open questions, each with
   `path:line`. Where your harness has no subagents, research the
   repositories one at a time yourself and write the same notes.
2. Read every note and spot-check its key claims against the code. A note
   is a map, not the territory.
3. Write `.feature/<ID>/research/context-map.md`: the services involved, how
   they talk today (calls, events, shared data), which interfaces and seams
   this feature touches, and who owns each side.
4. Look for open PRs in each repo that touch the same contracts or files
   (provider reference: H2). **Overlap with another feature is Tier 3**:
   stop and ask your human partner how to sequence.
5. Bring the open questions from the notes to your human partner; the
   answers go into the spec.

### 3. Spec - writing-unified-specs

Spec PR in the anchor repo. Gate: your human partner approves and merges it.

### 4. Plan and contract lock - locking-contracts-with-a-plan

Plan PR with the PR matrix, per-repo acceptance tests, rollout order and the
contract copies. Gate: the affected repos' code owners approve, your human
partner merges, and you run `fw lock <ID>`. The lock is the merged plan.

### 5. Code wave - dispatching-repo-workers

`fw dispatch <ID>` writes each worker's brief and launches one session per
repo. Each worker opens a draft PR as soon as its contracts are applied, so
reviewers can comment while the work happens. Then monitor:

```bash
fw status <ID>                       # branches, drift, PRs, unread mail
fw mail <ID> inbox --for coordinator # what the workers told you
```

### 6. Ripples

A ripple is anything that changes another repo's work: a contract change,
shared behavior, rollout order. When a worker reports one, or a review
raises one:

1. Tell the affected workers to pause the affected part
   (`fw mail <ID> send --from coordinator --to <repo> ...`).
2. Write the impact: what changes, which repos, which PRs.
3. Bring it to your human partner with options. If they choose a contract
   change, amend the plan (locking-contracts-with-a-plan), get it merged,
   re-lock, and tell the workers to re-apply contracts.

### 7. Verification - verifying-with-proof

Each worker proves its slice; you run the cross-repo end-to-end check and
collect the proof index.

### 8. Review - triaging-pr-feedback

Reviewers comment on the drafts as the work happens; workers triage their
own PRs. You handle ripples and keep the PRs consistent with each other.

### 9. Ready in merge order

Every PR stays a draft until its merge step comes, and people can comment on
it the whole time. You alone mark the feature's PRs ready (H7): a PR in the
current merge step - the lowest step with unmerged PRs - once its worker has
reported it complete, CI and the contract check are green and its threads
are answered. A ready PR that needs a large change goes back to draft (H7).
finishing-a-multi-repo-feature has the check.

### 10. Merge, rollout, cleanup - finishing-a-multi-repo-feature

## Bounded Autonomy

- Within a phase, keep going without check-ins until the phase's exit
  criteria are met or a Tier 3 question comes up.
- Between phases, stop: your human partner approves the spec, the plan, each
  merge and each rollout step.
- **Milestone runner (opt-in only):** if your human partner turns it on, you
  may advance through the plan's PR matrix on your own - marking each PR of
  the current merge step ready - whenever the deterministic gates hold (every
  earlier step merged, CI green, contract check passing, the worker reported
  the PR complete), within the turn or credit budget they set. You still
  never merge.
- Poll PRs or mail on a timer only when your human partner asks for it, and
  only while this session stays open.

## What You Never Do

- Edit, commit or push in another repo's worktree or main checkout.
- Merge or approve a PR, or set one to merge itself.
- Mark a PR ready before every PR in the earlier merge steps has merged.
- Unlock a contract (`fw unlock` is your human partner's command).
- Post to a team channel, a ticket comment or a cloud service unasked.
- Hand a worker a summary instead of a path to the document.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll make this one-line fix in service-b myself" | Message service-b's worker. The hook will stop you anyway. |
| "I'll summarize the plan for the workers" | Workers read the merged plan. Summaries drift. |
| "The workers can start before the plan merges" | The merged plan is the lock. Parallel work on an unlocked contract diverges. |
| "This contract tweak is tiny" | Every contract change is a ripple. Plan amendment, human approval. |
| "I'll spawn a subagent per repo, it's faster" | Subagents run in your directory and cannot ask your human partner. One session per worktree. |
| "Both PRs are green, I'll merge them" | Your human partner merges. |
| "Every PR is complete, I'll mark them all ready" | Only the current merge step. Later PRs stay drafts and keep collecting comments. |
| "I'll post the status to the channel" | Local by default. Ask first. |

## Commands

| Command | Use |
|---|---|
| `fw start <ID> --anchor A --repo B ...` | Worktrees and state |
| `fw config [<ID>] [--refresh]` | Team stack and provider references |
| `fw launch <ID> coordinator\|workers\|<repo> [--tmux]` | Open sessions |
| `fw lock <ID>` | Lock contracts from the merged plan |
| `fw dispatch <ID> [--tmux]` | Briefs + worker sessions |
| `fw status <ID>` | Dashboard |
| `fw mail <ID> send\|inbox ...` | Mailbox |
| `fw log-decision <ID> ...` | Decision log |
| `fw where` | Who and where this session is |
| `fw finish <ID>` | Cleanup after merge |

`fw help` lists every option.
