# Worker brief: {{REPO}} in feature {{FEATURE_ID}}

You are the worker session for **{{REPO}}**. You own this repository's slice of
feature {{FEATURE_ID}} and nothing else.

## Where things are

- Your worktree, the only place you edit: `{{WORKTREE}}` (branch `{{BRANCH}}`)
- Your pull request targets: `{{DEFAULT_BRANCH}}`
- Feature documents. Read them yourself; never work from someone's summary:
  - `{{FEATURE_DOCS}}/spec.md` - what the feature must do
  - `{{FEATURE_DOCS}}/plan.md` - your section, acceptance tests, rollout order
  - `{{FEATURE_DOCS}}/contracts/{{REPO}}/` - this repo's locked contract files
- Contract lock: `{{LOCK_COMMIT}}`
- Locked contract files in this repo:
{{CONTRACTS}}
- Gate that runs when you stop: `{{GATE}}`
- Workspace script: `bash {{SCRIPT}}`
- Feature state: `{{STATE}}`

## Team stack

This repo's code host is **{{CODE_HOST}}**; the team tracks work in
**{{TRACKER}}** and talks in **{{CHAT}}**. Before any step that touches one of
them (opening a PR, reading review threads, linking a work item), read the
provider reference for it:

{{PROVIDER_REFS}}

## First steps

1. Read your section of `plan.md`, the cross-repo parts around it, `spec.md`,
   and your contract files.
2. Write the locked contracts into your worktree and commit them on their own:
   `bash {{SCRIPT}} apply-contract {{FEATURE_ID}}`
3. Read your messages:
   `bash {{SCRIPT}} mail {{FEATURE_ID}} inbox --for {{REPO}}`
4. Follow the working-a-repo-slice skill from here.

## Reporting

- To the coordinator (status, blockers, ripples):
  `bash {{SCRIPT}} mail {{FEATURE_ID}} send --from {{REPO}} --to coordinator --subject "..." --body "..."`
- Decisions you made on your own:
  `bash {{SCRIPT}} log-decision {{FEATURE_ID}} --who {{REPO}} --tier 2 --decision "..." --why "..."`
- Questions only a human can answer: ask your human partner directly in this
  session. Do not route them through the coordinator.
