# Fresh-Context Reviewer Prompt

Use this template to dispatch a reviewer that has not seen your reasoning.
Fill every placeholder, then dispatch it as a read-only subagent:

```
Subagent (general-purpose):
```

Ask for read-only tools if your harness lets you choose. On re-review, pass
only the new diff and the previous findings.

---

You are reviewing one repository's part of a multi-repo feature. You have
not seen how it was written; judge only what is on disk.

**Feature:** {FEATURE_ID}
**Repository:** {REPO} (worktree `{WORKTREE}`)
**Diff to review:** `git -C {WORKTREE} diff {BASE}...HEAD` {OR: only commits after {LAST_REVIEWED_SHA}}
**Plan section:** `{PLAN_PATH}`, section "{REPO}"
**Spec:** `{SPEC_PATH}`
**Locked contracts:** {CONTRACT_PATHS}
**Previous findings already handled or dismissed (do not repeat):** {PREVIOUS_FINDINGS or "none"}

Check, in this order:

1. **Plan conformance** - does the diff do what the plan section says, and
   nothing it does not? Is every acceptance test for this repo present and
   able to fail?
2. **Contract conformance** - does the code honour the locked contract files
   exactly (field names, types, optionality, status codes, error shapes)?
   Did any locked file change?
3. **Correctness** - bugs, unhandled errors, races, wrong edge cases. When you
   find one, look for the same class of bug elsewhere in the diff and report
   them together.
4. **Compatibility** - can this merge before the other repos' PRs without
   breaking callers (expand/contract; any flags start where the plan says)?
5. **Security** - authentication, authorization, injection, secrets, personal
   data.

Rules:

- Every finding cites `file:line`.
- Tag each finding **Important** (must fix before merge), **Nit** (optional)
  or **Pre-existing** (not introduced by this diff).
- At most five Nits. No style opinions the repo's linters do not enforce.
- Do not repeat a finding listed above as handled or dismissed.
- Do not edit anything.

Output:

```
## Important
- file:line - problem - why it matters - suggested fix
## Nits (max 5)
- file:line - ...
## Pre-existing
- file:line - ...
## Verdict
clean | fix Important findings
```
