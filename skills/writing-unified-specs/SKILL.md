---
name: writing-unified-specs
description: Use when a multi-repo feature needs its specification written or revised before any implementation plan or code exists
---

# Writing Unified Specs

## Overview

One spec for the whole feature, written with your human partner, reviewed
as its own pull request in the anchor repo before anyone plans or codes.
The spec says what the feature must do and why; the plan (a separate PR)
says how each repository will do it.

**Core principle:** the hardest thinking happens here, at the highest
reasoning effort available, while changes are still cheap.

**Announce at start:** "I'm using the writing-unified-specs skill to write
the spec with you."

## Before You Write

- Raise reasoning effort to the highest level your session allows and work
  read-only (plan mode, where your harness has one) until your human
  partner approves the draft.
- If superpowers is installed, use its brainstorming skill for the
  conversation itself; this skill adds the multi-repo structure and the PR.
- Read the work item (provider reference T1) and the research from the
  coordinating skill: what each repo does today, where the seams are.

## The Conversation

- Ask one question at a time. Prefer multiple choice when the options are
  clear.
- Cover, in roughly this order: the problem and who has it, what success
  looks like, what is out of scope, the behavior in each scenario, which
  services are involved and how they talk, what data or contracts change
  (conceptually - exact schemas come in the plan), rollout and flags,
  failure modes, security and privacy, migration of existing data.
- Say what you would choose and why, then let your human partner decide.
- Stop when every section of the template has an answer or an explicit open
  question.

## Writing It

1. Copy `spec-template.md` (in this skill's folder) to
   `<anchor worktree>/<docs_dir>/<ID>/spec.md` and fill it in.
2. Keep it about behavior and boundaries. No code, no task lists.
3. Every acceptance criterion must be testable by someone who did not write
   the code.
4. Name the repos involved; the plan will give each one a section.

## The Spec PR

1. The anchor worktree is already on `<prefix><ID>-spec`. Commit only the
   spec.
2. Open a **draft** pull request in the anchor repo (provider reference H1)
   titled `<ID>: spec - <short name>`, linking the work item (T3), with the
   PR template's sections filled in (recording-decisions).
3. Ask your human partner to request reviewers: the people who own the
   behavior, plus each affected service's code owners if they want an early
   look.
4. Mark it ready (H7) when your human partner says the spec is complete.
   Until then it stays a draft that reviewers can comment on.

**Gate:** your human partner approves and merges the spec PR. Review
comments go through triaging-pr-feedback like any other PR.

## Revising a Merged Spec

A change after merge is a new spec PR (same branch name with a suffix, for
example `<prefix><ID>-spec-2`) that edits `spec.md` and states what changed
and why at the top. If the plan is already merged, check whether the change
is a ripple (coordinating-multi-repo-features).

## Red Flags

| Thought | Reality |
|---|---|
| "The ticket is clear enough, skip the spec" | Several repos will read this. Ambiguity multiplies per repo. |
| "I'll put the API schema in the spec" | Exact contracts belong in the plan, where they get locked. |
| "I'll answer the open questions myself" | Your human partner decides. Record what is still open. |
| "Spec and plan in one PR saves a round" | Different reviewers sign off on each, and the merged plan is the lock. Two PRs. |
