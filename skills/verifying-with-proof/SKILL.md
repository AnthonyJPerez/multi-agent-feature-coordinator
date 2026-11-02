---
name: verifying-with-proof
description: Use when about to claim a repository slice or a whole multi-repo feature works, before reporting a slice complete or marking a PR ready, or when reviewers ask for evidence
---

# Verifying With Proof

## Overview

"It works" is a claim. Proof is the command you ran, its output, and an
artifact anyone can re-check. Each worker proves its slice; the coordinator
proves the feature end to end; the docs PR carries an index of the evidence.

**Core principle:** evidence before claims, every time. With superpowers
installed, its verification-before-completion skill applies in full; this
skill adds where the evidence goes and the cross-repo check.

## Per Repository (worker)

1. Run, in your worktree, on the commit you are about to push:
   - the repo's gate command (your brief names it);
   - `fw contract-check <ID>`;
   - the plan's acceptance tests for this repo, by name;
   - typecheck and lint if the gate does not include them.
2. Save the evidence under `.feature/<ID>/proof/<repo>/`:
   ```
   proof/<repo>/<sha>/commands.md    each command, exit code, last lines of output
   proof/<repo>/<sha>/*.png|*.webm   screenshots or recordings for UI behavior
   ```
3. For UI or API behavior, capture it the way a reviewer would check it:
   browser automation (for example Playwright) against a local run,
   screenshots or a short recording; for APIs, the request and response.
4. Put the summary in the PR's Testing section with the commit SHA.

If anything fails, you do not have proof. Fix it or say plainly what is
failing.

## Whole Feature (coordinator)

1. When every repo's PR is green, run the cross-repo end-to-end check from
   the plan: start the services locally (the plan says how - for example a
   docker compose stack built from the feature worktrees), run each
   scenario, capture evidence.
2. Save it under `.feature/<ID>/proof/e2e/`.
3. Record failures as ripples or as findings for the owning worker.

## Proof Index (docs PR)

finishing-a-multi-repo-feature commits `<docs_dir>/<ID>/proof/README.md`: one
row per acceptance criterion with the test that covers it, the commit, and
where the evidence is. Commit small text evidence; store large media where
the team keeps it (Git LFS, an artifact store) and link it. Worktrees of an
LFS repo may hold pointer files only - run `git lfs pull` before relying on
them.

## Reviews and Cloud Services

Local checks are the default. Cloud review services, hosted previews and
cloud agents are opt-in: use them only when your human partner turns them on
for this feature.

## Red Flags

| Thought | Reality |
|---|---|
| "The tests passed earlier" | Run them on the commit you push. |
| "It compiles, so it works" | Compiling is not an acceptance test. |
| "The E2E is too much setup" | It is in the plan. If it cannot run, say so; do not skip it silently. |
| "I'll describe what the screen shows" | Capture it. |
