---
name: finishing-a-multi-repo-feature
description: Use when a multi-repo feature's pull requests are complete and waiting for their merge step, approved or merged, when rolling the feature out, or when cleaning up its worktrees and branches
---

# Finishing a Multi-Repo Feature

## Overview

The feature lands one merge step at a time, in the order the plan says,
and rolls out the way the plan says: through feature flags if the plan uses
them, or with the merges themselves if it does not. You mark each step's PRs
ready when their turn comes; reviewers approve them; your human partner
merges them and makes every rollout change. You also keep the remaining
branches current, write the docs PR, close the work item and clean up.

**Core principle:** merge order, feature flags and rollout order come from
the merged plan. A PR leaves draft only when its merge step comes, and every
merge and flag change is a human action.

**Announce at start:** "I'm using the finishing-a-multi-repo-feature skill to
land <ID>."

## 1. Mark the Current Step Ready (coordinator)

The current step is the lowest merge step in the plan's PR matrix that still
has unmerged PRs. Mark a PR ready (H7) when it is in the current step and:

- its worker reported it complete;
- CI is green and the contract check passes (`fw status <ID>` shows `ok`);
- its decision block is present and its review threads are answered;
- the PRs it depends on are merged.

Mark no other PR ready. PRs in later steps stay drafts: reviewers can keep
commenting and their workers keep answering. Each time you mark a PR ready,
tell your human partner it is up for approval and merge, with the table for
the step.

Before your human partner merges a ready PR, check again: required human
approvals on its current commit (not an older one), CI green. Approval rules
the team should have on the code host: approvals dismissed on new commits,
at least one non-author human approver on cross-service code PRs, a second
approver for high-risk changes, code owners on contract and protected paths.
The provider reference (H8) says where each setting lives.

## 2. Merging (your human partner)

- They merge the ready PRs; any feature flags stay where the plan says they
  start. PRs that share a step can merge in any order. Use the code host's merge queue if the team has one. Repos
  without a pull-request system are merged from the main checkout (provider
  reference `local.md`). When the last PR of a step has merged, go back to 1
  for the next step.
- After each merge, the workers whose PRs come later bring their branch up
  to date by **merging** the default branch (never rebasing), re-run the
  gate and push. Mail them: `fw mail <ID> send --from coordinator --to <repo> --subject "Update from main" ...`.
- Stacked sub-PRs are squash-merged into their feature branch before that
  branch's PR merges.

## 3. Docs PR (coordinator)

It is the last step. On a new `<prefix><ID>-docs` branch in the anchor
worktree (from the updated default branch), open it as a draft (H1) and mark
it ready (H7) once it is complete. It holds:

- `<docs_dir>/<ID>/decisions.md` - copy of `.feature/<ID>/decisions.md`;
- `<docs_dir>/<ID>/proof/README.md` - the proof index (verifying-with-proof);
- internal docs that changed with the feature (runbooks, architecture notes).

Customer-facing docs go in a PR to the docs repository if the team has one;
your human partner owns that PR like the others. Docs code owners review.

## 4. Rollout (your human partner)

If the plan uses feature flags, follow its flag table in order. For each
change, prepare: what changes, for whom, what to watch, how to roll it back.
Your human partner makes the change. If the plan uses no flags, the merges
were the rollout: after each merge step, check what the plan says to watch
and keep its revert steps at hand. Record each step with `fw log-decision`.

## 5. Close Out

1. Update the work item (provider reference T5): link every merged PR, move
   it to done if the team's process says the engineer does that.
2. Clean up:
   ```bash
   fw finish <ID>
   ```
   It refuses while any branch has unmerged commits or a worktree has
   uncommitted changes, and lists them. It removes the worktrees, deletes the
   local branches and archives `.feature/<ID>/`. `--keep-branches` and
   `--keep-state` keep those. `--force` discards unmerged work - only your
   human partner runs that.
3. Tell your human partner what was cleaned up and anything left open.

## Red Flags

| Thought | Reality |
|---|---|
| "All PRs are approved, merge them together" | Plan order, one step at a time. |
| "Every PR is complete, mark them all ready" | Only the current step. Later steps stay drafts. |
| "I'll rebase the remaining branches onto main" | Merge main in. Rebasing pushed branches breaks reviews and sub-PRs. |
| "Change all the flags at once, it's all merged" | The plan's flag order, one change at a time, by your human partner. |
| "finish refused, I'll use --force" | Find out why. Unmerged work is somebody's work. |
