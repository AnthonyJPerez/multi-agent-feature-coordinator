---
name: working-a-repo-slice
description: Use when this session is a worker in one repository's feature worktree, or when implementing one repository's part of a locked multi-repo plan
---

# Working a Repo Slice

## Overview

You own one repository's part of a feature. The merged plan says what to
build, the locked contract files say exactly what crosses the boundary, and
your brief says where everything is. You open a draft PR early, build in the
open, answer review comments as they arrive, prove the slice works and tell
the coordinator when it is complete - asking your human partner directly when
a decision is theirs.

**Core principle:** implement the merged plan against the locked contracts,
inside this worktree, in a draft PR people can comment on from the start. The
coordinator marks it ready when its turn in the plan's merge order comes.

**Announce at start:** "I'm using the working-a-repo-slice skill to implement
<repo>'s part of <ID>."

## Start

1. Read your brief (`.feature/<ID>/briefs/worker-<repo>.md`; the session
   context and `fw where` give the path). Then read, yourself:
   - your repo's section of `plan.md`, the PR matrix (your merge step) and
     the rollout order;
   - `spec.md`;
   - your locked contract files under `contracts/<repo>/`.
2. Write the locked contracts into your worktree and commit them alone:
   ```bash
   fw apply-contract <ID>
   git add <files it wrote> && git commit -m "<ID>: apply locked contracts"
   ```
3. Open the draft PR now (next section).
4. Read your mail: `fw mail <ID> inbox --for <repo>`.
5. Break your section into tasks and track them.

## Open the Draft PR Early

Reviewers can comment while you build; a comment on day one costs less than
the same comment at the end.

1. Push the branch (`git push -u origin <branch>`).
2. Open a **draft** PR against the default branch (provider reference H1):
   - title `<ID>: <repo> - <short description>`;
   - body from the PR template (recording-decisions): summary, plan section
     link, merge step, Assumptions & Autonomous Decisions, Testing, Risk, How
     to revert. Fill in what you know; mark the rest "in progress";
   - link the work item (T3).
3. Mail the coordinator the PR link.

Push whenever a task is done and keep the PR body's decision block current.
Comments on the draft go through triaging-pr-feedback, between tasks. The PR
stays a draft until the coordinator marks it ready.

## Implement

- Work test-first in small steps (with superpowers installed, use its
  test-driven-development skill). The plan's acceptance tests for this repo
  are your definition of done.
- Generated code from the contracts (clients, stubs, types) is fine to
  regenerate. The contract files themselves are locked: the guard hook
  blocks edits, and the Stop gate reports drift.
- Keep the branch current by **merging** the default branch in
  (`git merge origin/<default branch>`); never rebase a pushed feature branch.
- Decisions as you go - see recording-decisions:
  - Tier 1 (mechanical, inside the plan): just do it.
  - Tier 2 (a local design choice): `fw log-decision <ID> --tier 2 ...` and
    put it in the PR's decision block.
  - Tier 3: stop and ask your human partner directly in this session.

## Ripples

Something in your repo needs another repo to change, or the contract is
wrong or incomplete: **stop that part of the work** and tell the coordinator.

```bash
fw mail <ID> send --from <repo> --to coordinator --subject "Ripple: ..." --body "What I found, which contract or behavior, which repos, options I see"
```

Carry on with unaffected tasks while you wait. Do not patch around the
contract.

## The Stop Gate

When you finish a turn, a hook runs `fw contract-check` and your repo's gate
command (the brief names it). If they fail, it blocks the stop and shows you
the log tail - fix it. If you need to stop to ask your human partner
something, say so and stop again without changing anything; the gate does
not block twice on the same state.

## Review Your Own Diff With Fresh Eyes

Before you report the slice complete (and after large changes), dispatch a
reviewer that has not seen your reasoning, using `reviewer-prompt.md` in this
skill's folder. Fill in the placeholders; give it the plan section and
contract paths, not your summary. Fix Important findings; note the rest in
the PR.

## Prove It - verifying-with-proof

Run the acceptance tests and the gate, and save the evidence under
`.feature/<ID>/proof/<repo>/` before claiming anything works.

## Report the Slice Complete

When the acceptance tests pass, the proof is saved, the fresh review is
clean, the gate and CI are green and every review thread is answered:

1. Update the PR body: Testing (commands, evidence location), the decision
   block, Risk.
2. Tell the coordinator:
   ```bash
   fw mail <ID> send --from <repo> --to coordinator --subject "Complete: <repo>" --body "PR <link> at <sha>; proof in .feature/<ID>/proof/<repo>/; open threads: <none, or which>"
   ```
3. Leave the PR in draft. The coordinator marks it ready (H7) once every PR
   in an earlier merge step has merged; reviewers approve it then.

Keep answering comments while you wait, and tell the coordinator about every
push after you reported complete. If a PR that is already ready needs a large
change, put it back to draft (H7) and tell the coordinator why.

## Reviews

Comments on your PR, draft or ready: triaging-pr-feedback. Never apply all
comments at once.

## Never

- Edit outside this worktree (the hook blocks it; message the coordinator).
- Change a locked contract file, or run `fw unlock`.
- Mark your feature PR ready for review: the coordinator does that, in merge
  order.
- Merge or approve your PR, or set it to merge itself.
- Rewrite pushed history: no force push, no rebase of the feature branch.

## Red Flags

| Thought | Reality |
|---|---|
| "The coordinator told me what to do, I'll skip the plan" | Read the plan. The message points at it; it does not replace it. |
| "I'll open the PR once the work is finished" | Open the draft now. Early comments cost less than late ones. |
| "The contract has a typo, I'll just fix it" | Ripple. Mail the coordinator. |
| "I'll ask the coordinator to ask the human" | Ask your human partner directly. Relays lose detail. |
| "Tests pass, I'll mark it ready" | Proof first, then report complete. The coordinator marks PRs ready in merge order. |
| "Rebase makes the history cleaner" | Merge. Rebasing pushed branches breaks sub-PRs and reviews. |
