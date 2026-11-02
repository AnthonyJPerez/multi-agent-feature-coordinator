---
name: dispatching-repo-workers
description: Use when a multi-repo feature's plan is merged and locked and per-repository implementation should start, or when worker sessions need to be relaunched, monitored or redirected
---

# Dispatching Repo Workers

## Overview

One worker session per repository, all started at once, each in its own
feature worktree, each with a brief that points at the merged plan and its
locked contracts. You monitor through the mailbox and `fw status`; each
worker owns its PR and talks to your human partner directly when it needs a
decision.

**Core principle:** a worker gets paths, not paraphrases. Everything it needs
is in the merged plan, the contract files and its brief.

**Announce at start:** "I'm using the dispatching-repo-workers skill to start
the repo workers."

## Preconditions

- `fw status <ID>` shows a contract lock. No lock: stop and finish
  locking-contracts-with-a-plan. (`--allow-unlocked` exists for features
  with no cross-service contract at all; use it only when your human partner
  agrees there is none.)
- Every participating repo has a worktree. Missing one: `fw start <ID>
  --anchor <anchor> --repo <repo>` adds it.

## Dispatch

```bash
fw dispatch <ID>              # writes briefs, prints one launch command per repo
fw dispatch <ID> --tmux       # or starts them all in tmux session fc-<ID>
fw dispatch <ID> --cli copilot
```

- The default CLI and models come from the team config (`default_cli`,
  `worker_model`, `model.<repo>` for repos that deserve a stronger model -
  auth, billing, migrations).
- Without `--tmux`, give the printed commands to your human partner: each one
  opens a session in its worktree. On harnesses with background sessions
  they may run them that way instead (see your harness reference).
- Each brief lands in `.feature/<ID>/briefs/worker-<repo>.md`. Read one
  before sending people off; fix the plan, not the brief, if something is
  wrong (briefs are regenerated on every dispatch).

## A Worker's Goal

Give every worker the same bounded goal, using its harness's goal or
autopilot feature with a turn or credit cap where it has one:

> Draft PR open on `<branch>` in `<repo>` from the start; the plan's
> acceptance tests for this repo pass; `fw contract-check` passes; a
> fresh-context review has no Important findings; the PR carries its
> decision block; "Complete" mailed to the coordinator.

The PR is still a draft when the goal is met: you mark it ready when its
merge step comes (finishing-a-multi-repo-feature).

Workers stop and ask their human partner on anything Tier 3.

## Monitoring

```bash
fw status <ID>
fw mail <ID> inbox --for coordinator
```

- **Contracts: DRIFT** - the worker changed a locked file. Ask why; it is
  either a mistake (it runs `fw apply-contract`) or a ripple.
- **Unread mail piling up** for a worker - it is not reading its inbox; ask
  your human partner to nudge that session.
- Check in on a timer only if your human partner asks for it, and only while
  your session stays open.

## Redirecting a Worker

```bash
fw mail <ID> send --from coordinator --to <repo> --subject "..." --body "..."
```

Say what changed and point to the file that says so (`plan.md` section,
amendment PR). For anything urgent, also tell your human partner so they can
switch to that session. Where your harness can message other sessions
directly, use that only to tell the worker to read its mail.

## Relaunching

A worker session closed or lost its context: `fw launch <ID> <repo>`. The
brief and mailbox are on disk, so a fresh session picks up from them plus
its own branch history.

## Do Not

- Use subagents, agent teams or fleet-style fan-out as repo writers - they
  share your working directory, skip the repo's hooks and cannot ask your
  human partner anything.
- Edit a worker's repository yourself.
- Paste the plan into the brief.

## Red Flags

| Thought | Reality |
|---|---|
| "The plan PR is approved, I'll dispatch before it merges" | The lock is the merged plan. Wait. |
| "I'll give each worker a short summary instead of the brief" | The brief points at the documents. Summaries drift. |
| "One worker is slow, I'll do its part" | Message it, or ask your human partner. Never edit another repo. |
