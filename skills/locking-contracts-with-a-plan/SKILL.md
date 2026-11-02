---
name: locking-contracts-with-a-plan
description: Use when a multi-repo feature's spec is approved and the implementation plan, cross-service contracts, or rollout order need to be written, amended, or locked
---

# Locking Contracts With a Plan

## Overview

The plan turns the approved spec into one section per repository, an order
for the pull requests, a rollout sequence, and the exact contract files that
cross service boundaries. When the plan PR merges, `fw lock` records those
contract files. From then on every worker implements against the same
bytes, and a Stop gate catches drift.

**Core principle:** contracts are files, not prose. Lock the bytes.

**Announce at start:** "I'm using the locking-contracts-with-a-plan skill to
write the plan and lock the contracts."

## Prerequisites

- The spec PR is merged. If not, stop: writing-unified-specs.
- Update the anchor worktree and start the plan branch from the merged
  default branch:
  ```bash
  git fetch origin
  git switch -c <prefix><ID>-plan origin/<default branch>
  ```

## What Goes In

Copy `plan-template.md` (this skill's folder) to
`<docs_dir>/<ID>/plan.md` and fill in:

1. **PR matrix** - every PR the feature needs (code PRs per repo, docs PR,
   any migration PR), its dependencies, and its merge step. PRs that share a
   step can merge in any order; a step starts only when every PR in the
   earlier steps has merged. Each PR stays a draft until its step comes.
2. **One section per repository** - what changes, which files or modules,
   the acceptance tests that prove it (each tied to a spec criterion), and
   the gate command if the team config does not already set one. Start from
   the repository's research note (`.feature/<ID>/research/<repo>.md`): its
   entry points, tests, owners and flags; check anything that changed since.
3. **Contracts** - for every contract that crosses a boundary (OpenAPI,
   protobuf, GraphQL, event or message schemas, shared config), the exact
   file as it must exist in the owning repo after the change:
   ```
   <docs_dir>/<ID>/contracts/<repo>/<path inside that repo>
   ```
   for example `docs/features/PAY-42/contracts/billing-service/api/openapi.yaml`.
   Copy the current file from the repo's worktree and edit it; never retype
   it from memory.
4. **Compatibility rule** - expand, then contract: add new fields and
   endpoints first, migrate callers, remove old ones in a later PR. No PR may
   break a caller that merges after it.
5. **Feature flags and rollout** - whether the feature uses feature flags at
   all, and why. If it does: each flag's name, whether it starts on or off
   and why, the order to change them, and how to roll each one back. If it
   does not: the merge steps are the rollout, so say what each step changes
   for users and how to revert it. Your human partner decides; this is
   where the decision is recorded.
6. **Decisions** - the cross-repo decisions made so far and why
   (recording-decisions).

## Check the Contracts

- Run the breaking-change checker the repo already uses, against the
  repo's current version: for example `buf breaking`, `oasdiff breaking`,
  `graphql-inspector diff`. If none exists, diff by hand and list every
  removed or changed field.
- Anything breaking needs the expand/contract steps spelled out in the PR
  matrix, or your human partner's explicit approval.

## Fresh-Eyes Critique

Before opening the PR, dispatch a reviewer that has not seen your reasoning:

```
Subagent (general-purpose):
  Review <docs_dir>/<ID>/plan.md and its contracts/ against spec.md.
  Report, with file:line: contract fields the spec needs but the plan lacks;
  repo sections that depend on each other in a way the PR matrix does not
  order; breaking changes without expand/contract steps; acceptance tests
  that cannot fail. Important findings first, at most five nits.
```

Fix the Important findings; mention the rest to your human partner.

## The Plan PR

1. Commit `plan.md` and `contracts/` (nothing else) and open a draft PR in the
   anchor repo titled `<ID>: plan - <short name>` (provider reference H1),
   linking the work item (T3), with the decision block.
2. List each affected repository's code owners in the PR description and ask
   your human partner to request them as reviewers. The code host cannot
   request owners of other repositories automatically.
3. Mark it ready (H7) when your human partner says the plan is complete.
   Until then it stays a draft that reviewers can comment on.
4. **Gate:** those owners approve and your human partner merges.

## Lock

After the merge:

```bash
fw lock <ID>          # reads contracts/ at origin/<default branch>
```

It prints every locked file per repo. Tell your human partner the lock
commit, then continue with dispatching-repo-workers.

`fw lock` refuses if it finds no contract copies at the merged ref - that
usually means the plan PR has not merged yet.

## Amending a Locked Plan

A contract change after the lock is a ripple and always Tier 3:

1. Workers pause the affected work (coordinating-multi-repo-features,
   Ripples).
2. Your human partner decides. If a worker must change a locked file before
   the amendment merges, your human partner runs
   `fw unlock <ID> --repo <repo> --path <path> --reason "..."` themselves.
3. Open an amendment PR on `<prefix><ID>-plan-2` (then `-3`, ...) that edits
   the contract copies and adds a dated "Amendments" entry to `plan.md`.
4. After it merges: `fw lock <ID>` again, and mail every affected worker to
   run `fw apply-contract <ID>` and commit.

## Red Flags

| Thought | Reality |
|---|---|
| "I'll describe the new fields in prose" | Workers will each read the prose differently. Commit the file. |
| "I'll lock from my branch, the PR is basically approved" | The lock is the merged plan, nothing else. |
| "The schema change is backwards compatible, skip the checker" | Run it. "Compatible" is a claim; the checker is evidence. |
| "I'll merge both halves of the change together" | Expand/contract: each PR stays safe for callers that merge later. |
