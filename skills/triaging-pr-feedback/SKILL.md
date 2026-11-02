---
name: triaging-pr-feedback
description: Use when pull request review comments, review threads or requested changes arrive on any feature PR, before changing any code in response
---

# Triaging PR Feedback

## Overview

Review feedback is input to a decision, not a to-do list. Read every open
thread, sort each one into a bucket, handle ripples first, fix what is small
and clear, take everything else to your human partner, and answer every
thread with what was decided and why.

**Core principle:** triage before you touch code. Applying every comment
blindly is how one review becomes fifty rounds.

**Announce at start:** "I'm using the triaging-pr-feedback skill to triage
the review on <PR>."

**Never** use one-shot "fix all feedback" commands (`/pr fix feedback`,
`/pr auto` or similar). They apply everything, including what should be
pushed back on, and loop until merge.

## 1. Collect

- Read every unresolved review thread and top-level review comment on the PR
  (provider reference H3), with the file and line each one points at.
- Note the review round: how many times this PR has been through review and
  fix.
- With superpowers installed, its receiving-code-review skill governs how you
  weigh each comment technically; this skill adds the buckets, ripples and
  multi-repo rules.

## 2. Sort Into Buckets

Check in this order - the first bucket that fits wins:

| Bucket | What it is | What happens |
|---|---|---|
| **Ripple** | Changes a contract, shared behavior or the rollout order - anything another repo depends on | Stop work on it. Mail the coordinator (worker) or run the ripple steps (coordinator). Reply on the thread that it is being handled across repos. |
| **Small** | Clear, local, inside the plan, under about 30 lines | Fix it, push, reply with the commit SHA. |
| **Ambiguity** | The comment can be read more than one way, or the right answer is a judgment call | Write 2-3 options with a recommendation; ask your human partner; then act. |
| **Large** | Clear but big - new module, wide refactor, more than about 30 lines | Ask your human partner: in this PR, or a stacked sub-PR? |
| **Disagree** | You believe the comment is wrong | Reply with the technical reason and evidence; your human partner decides if the reviewer insists. |
| **Pre-existing** | The problem exists on the default branch, not introduced here | Acknowledge, keep it out of this PR, offer a follow-up work item. |

Show your human partner the triage table (thread, bucket, proposed action)
before changing anything beyond the Small bucket.

## 3. Act

- **Ripples first.** They can invalidate other fixes.
- **Small:** one commit per comment or per bug class. If the comment points
  at a class of bug, fix every instance in the diff and say so.
- **Large as a sub-PR:** branch `<prefix><ID>--sub-<slug>` from the feature
  branch, open the PR with the feature branch as its base (H6), link it from
  the thread. It is squash-merged into the feature branch later.
- Run the gate and the relevant tests before pushing (verifying-with-proof).
- Push, then reply on each thread (H4) using `reply-templates.md`: what you
  did, the commit SHA, and the decision block for anything you chose.
- Resolve a thread (H5) only when your team lets authors resolve and the
  reviewer's concern is fully addressed; otherwise leave it for the reviewer.

## 4. Converge

- After the first round, ask for re-review of the **new diff only**, listing
  the threads you addressed.
- Do not reopen points a reviewer already accepted, and do not argue the
  same point twice.
- Nits: fix at most five per round; batch the rest or decline politely.
- **After three review rounds on the same PR, stop fixing.** Step back with
  your human partner: summarize what keeps coming back and propose an
  alternative approach (split the PR, change the design, talk to the
  reviewer). Continuing to patch is not an option.

## 5. Report

- Worker: mail the coordinator a one-line status per PR (round, open
  threads, waiting on whom).
- Log Tier 2 and 3 decisions (`fw log-decision`).

## Approvals

- Approvals belong to people. An agent's approval never counts, and you never
  approve or merge.
- An approval covers one commit. Pushing new commits means asking for
  approval again; where the code host can dismiss stale approvals, the team
  should have that on.
- Cross-service code PRs need at least one human approver who is not the
  author.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll just address all the comments" | Triage first. Some are ripples, some are wrong. |
| "This change to the response shape is small" | It is a contract. Ripple. |
| "The reviewer will be happier if I fix every nit" | Five per round. Rounds cost more than nits. |
| "Round four will get it" | Three rounds, then step back and propose something different. |
| "I'll resolve the threads to tidy up" | Only when your team lets authors resolve and the concern is addressed. |
