---
name: recording-decisions
description: Use when making an assumption or a design choice nobody explicitly asked for, before opening or updating a pull request, or when a decision may need your human partner's sign-off
---

# Recording Decisions

## Overview

Agents make many small choices while implementing. Reviewers and your human
partner can only trust the result if those choices are visible. Every choice
gets a tier; Tier 2 and 3 choices are logged and travel with the push that
contains them.

**Core principle:** no silent assumptions. If you chose it and nobody asked
for it, it is written down where the reviewer will see it.

## Tiers

| Tier | What | Action |
|---|---|---|
| **1 - silent** | Mechanical work the plan already decided: naming inside conventions, wiring, tests for specified behavior | Just do it. |
| **2 - log and continue** | A local design choice inside one repo that the plan left open: a library function over another, an error message, a retry count | Log it, put it in the PR's decision block, keep going. |
| **3 - stop and ask** | See the list below | Stop. Ask your human partner with options and a recommendation. Act only on their answer. |

**Always Tier 3:**

- Any change to a locked contract, or anything another repo depends on (a
  ripple).
- Authentication, authorization, billing, payments, secrets, personal data.
- Data migrations and anything that cannot be undone.
- New dependencies, dependency upgrades, build or CI changes.
- Paths in the team's `protected_paths` (the guard hook asks or blocks).
- Overlap with another feature's open PRs.
- A missing secret, credential or environment you would have to invent.
- The third review round on the same PR.
- Anything your human partner said to check with them.

## Logging

```bash
fw log-decision <ID> --who <repo|coordinator> --tier 2 \
  --decision "What you chose" --why "Why" \
  [--alternatives "What else was possible"] [--pr <url>]
```

The log is `.feature/<ID>/decisions.md`. It is local while the feature runs;
finishing-a-multi-repo-feature commits it with the docs PR.

## The Decision Block

Every push that contains a Tier 2 or 3 decision carries a block - in the PR
description when you open it, and in a PR comment or thread reply when you
push later. Format: `decision-block.md` in this skill's folder. A push with
no decisions says so: "No new autonomous decisions."

## The PR Template

`templates/pull_request_template.md` (this skill's folder) has the sections
every feature PR needs: summary, plan link, Assumptions & Autonomous
Decisions, Testing, Risk, How to revert. If the repo has its own template,
keep it and add the missing sections. Where the template file lives depends
on the code host (provider reference H9); suggest committing one to your
human partner if the repo has none - do not add it unasked.

## Asking a Tier 3 Question

- Ask your human partner directly in this session (workers too - do not
  relay through the coordinator).
- One question at a time: the situation in two sentences, 2-3 options with
  consequences, your recommendation.
- While you wait, keep working on parts the answer cannot affect.
- Record the answer as a decision with `--tier 3`.

## Red Flags

| Thought | Reality |
|---|---|
| "It's obvious, no need to mention it" | Obvious to you. Write one line. |
| "I'll collect the decisions at the end" | They travel with the push that contains them. |
| "Adding this small library is fine" | New dependency: Tier 3. |
| "My human partner is busy, I'll pick the safe option" | Tier 3 means ask. Work on something else meanwhile. |
