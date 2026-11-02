---
name: working-a-repo-slice
description: Use when this session is a worker in one repository's feature worktree, or when implementing one repository's part of a locked multi-repo plan
---

# Working a Repo Slice

## Overview

You own one repository's part of a feature. The merged plan says what to
build, the locked contract files say exactly what crosses the boundary, and
your brief says where everything is. You implement, verify, open the PR and
answer its reviews - asking your human partner directly when a decision is
theirs.

**Core principle:** implement the merged plan against the locked contracts,
inside this worktree, and surface every decision you make.

**Announce at start:** "I'm using the working-a-repo-slice skill to implement
<repo>'s part of <ID>."

## Start

1. Read your brief (`.feature/<ID>/briefs/worker-<repo>.md`; the session
   context and `fw where` give the path). Then read, yourself:
   - your repo's section of `plan.md`, the PR matrix and the rollout order;
   - `spec.md`;
   - your locked contract files under `contracts/<repo>/`.
2. Write the locked contracts into your worktree and commit them alone:
   ```bash
   fw apply-contract <ID>
   git add <files it wrote> && git commit -m "<ID>: apply locked contracts"
   ```
3. Read your mail: `fw mail <ID> inbox --for <repo>`.
4. Break your section into tasks and track them.

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

Before opening the PR (and after large changes), dispatch a reviewer that has
not seen your reasoning, using `reviewer-prompt.md` in this skill's folder.
Fill in the placeholders; give it the plan section and contract paths, not
your summary. Fix Important findings; note the rest in the PR.

## Prove It - verifying-with-proof

Run the acceptance tests and the gate, and save the evidence under
`.feature/<ID>/proof/<repo>/` before claiming anything works.

## Open the PR

1. Push the branch (`git push -u origin <branch>`).
2. Open a **draft** PR against the default branch (provider reference H1):
   - title `<ID>: <repo> - <short description>`;
   - body from the PR template (recording-decisions): summary, plan section
     link, Assumptions & Autonomous Decisions, Testing, Risk, How to revert;
   - link the work item (T3).
3. When verification is done and the review is clean, mark it ready (H7) and
   mail the coordinator the PR link and its state.

## Reviews

Comments on your PR: triaging-pr-feedback. Never apply all comments at once.

## Never

- Edit outside this worktree (the hook blocks it; message the coordinator).
- Change a locked contract file, or run `fw unlock`.
- Merge or approve your PR, or set it to merge itself.
- Rewrite pushed history: no force push, no rebase of the feature branch.

## Red Flags

| Thought | Reality |
|---|---|
| "The coordinator told me what to do, I'll skip the plan" | Read the plan. The message points at it; it does not replace it. |
| "The contract has a typo, I'll just fix it" | Ripple. Mail the coordinator. |
| "I'll ask the coordinator to ask the human" | Ask your human partner directly. Relays lose detail. |
| "Tests pass locally, I'll mark it ready" | Proof first: evidence saved, fresh review clean. |
| "Rebase makes the history cleaner" | Merge. Rebasing pushed branches breaks sub-PRs and reviews. |
