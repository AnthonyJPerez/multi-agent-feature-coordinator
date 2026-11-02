# Repository Research Prompt

Dispatch one per participating repository, in parallel, before the spec:

```
Subagent (general-purpose):
  description: "Research {{REPO}} for {{ID}}"
  prompt: (below, placeholders filled)
```

Fill in `{{ID}}`, `{{REPO}}`, `{{WORKTREE}}` (the repo's feature worktree),
`{{FEATURE}}` (the work item text or your human partner's description, as
written - not your summary) and `{{OUTPUT}}`
(`.feature/{{ID}}/research/{{REPO}}.md`).

---

You are researching one repository, **{{REPO}}**, for feature {{ID}}. Read
only: apart from writing your note, do not edit, commit, run migrations or
call services. Your note is what the spec, the plan and this repository's
worker will start from, so every claim needs a `path:line` behind it.

The feature, as written:

> {{FEATURE}}

The repository is at `{{WORKTREE}}`. Use absolute paths under it.

1. Read the repository's own instructions first: `CLAUDE.md`, `AGENTS.md`,
   `.github/copilot-instructions.md`, `CONTRIBUTING*`, `CODEOWNERS`, and the
   README. Follow their conventions in what you report.
2. Find what the feature will touch, and write `{{OUTPUT}}` with these
   sections:
   - **Summary** - what this repository does, in two or three sentences,
     and its role in this feature.
   - **Where the feature lands** - entry points, modules and files, with
     `path:line`.
   - **Interfaces it exposes** - APIs, events, schemas, shared config, with
     the contract file paths (OpenAPI, protobuf, GraphQL, event schemas).
   - **Interfaces it consumes** - other services, queues, databases it calls
     or reads, and where.
   - **Data** - stores, tables or collections involved; how migrations are
     done here.
   - **Tests and gate** - the test, lint and build commands, and where tests
     for this area live.
   - **Owners** - code owners of the paths above.
   - **Flags and rollout** - the feature flag system this repository uses,
     if any, and how it deploys.
   - **Risks and constraints** - what could break, compatibility concerns,
     performance or security notes.
   - **Open questions** - what you could not determine from the code.
   - **Overlapping work** - branches or open pull requests touching the same
     files, if you can see them.
3. State what you looked at and what you did not. Mark anything you inferred
   rather than read as inferred.
4. Reply with only: the path you wrote, and the three findings most likely to
   change the spec or the plan.
