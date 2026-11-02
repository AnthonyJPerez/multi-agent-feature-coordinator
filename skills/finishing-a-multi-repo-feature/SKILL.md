---
name: finishing-a-multi-repo-feature
description: Use when all of a multi-repo feature's pull requests are approved or merged, when rolling out its flags, or when cleaning up its worktrees and branches
---

# Finishing a Multi-Repo Feature

## Overview

The feature lands in the order the plan says, with flags off, then turns on
step by step. Your human partner merges and flips; you prepare each step,
keep the remaining branches current, write the docs PR, close the work item
and clean up.

**Core principle:** merge order and rollout order come from the merged plan,
and every merge and flag flip is a human action.

**Announce at start:** "I'm using the finishing-a-multi-repo-feature skill to
land <ID>."

## 1. Ready Check (coordinator)

For each PR in the plan's matrix, in merge order:

- required human approvals present - on the current commit, not an older one;
- CI green; contract check passing (`fw status <ID>` shows `ok`);
- decision block present; review threads resolved or answered;
- the PRs it depends on are merged.

Give your human partner the table and the next PR to merge. Approval rules
the team should have on the code host: approvals dismissed on new commits,
at least one non-author human approver on cross-service code PRs, a second
approver for high-risk changes, code owners on contract and protected paths.
The provider reference (H8) says where each setting lives.

## 2. Merging (your human partner)

- They merge each PR, in order, flags off. Use the code host's merge queue
  if the team has one.
- After each merge, the workers whose PRs come later bring their branch up
  to date by **merging** the default branch (never rebasing), re-run the
  gate and push. Mail them: `fw mail <ID> send --from coordinator --to <repo> --subject "Update from main" ...`.
- Stacked sub-PRs are squash-merged into their feature branch before that
  branch's PR merges.

## 3. Docs PR (coordinator)

On a new `<prefix><ID>-docs` branch in the anchor worktree (from the updated
default branch):

- `<docs_dir>/<ID>/decisions.md` - copy of `.feature/<ID>/decisions.md`;
- `<docs_dir>/<ID>/proof/README.md` - the proof index (verifying-with-proof);
- internal docs that changed with the feature (runbooks, architecture notes).

Customer-facing docs go in a PR to the docs repository if the team has one;
your human partner owns that PR like the others. Docs code owners review.

## 4. Rollout (your human partner)

Follow the plan's flag table in order. For each step, prepare: what turns
on, for whom, what to watch, how to turn it off. Your human partner flips
it. Record each step with `fw log-decision`.

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
| "All PRs are approved, merge them together" | Plan order, one at a time, flags off. |
| "I'll rebase the remaining branches onto main" | Merge main in. Rebasing pushed branches breaks reviews and sub-PRs. |
| "Turn all flags on, it's all merged" | Plan order, one step at a time, by your human partner. |
| "finish refused, I'll use --force" | Find out why. Unmerged work is somebody's work. |
