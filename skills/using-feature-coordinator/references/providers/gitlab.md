# GitLab (code host) and GitLab Issues (tracker)

CLI: `glab`, logged in as your human partner (`glab auth status`). Run from
the repo's worktree, or pass `-R group/subgroup/project`. In `glab api`,
`:fullpath` and `:id` are replaced with the current project. The GitLab MCP
server, if connected, covers the same actions.

## Code host

**H1 - open a draft MR**

```bash
glab mr create --draft --source-branch "<branch>" --target-branch main \
  --title "<ID>: <repo> - <summary>" --description "$(cat "<state>/mr-body.md")" --yes
```

**H2 - status and overlapping MRs**

```bash
glab mr view <iid> -F json          # state, draft, approvals, pipeline
glab ci status --branch "<branch>"
glab mr list --all -F json          # filter by changed paths with glab api .../merge_requests/<iid>/diffs
```

**H3 - review threads (discussions)**

```bash
glab api "projects/:fullpath/merge_requests/<iid>/discussions"
```

Each discussion has an `id`, `notes[]` (with `position` for diff notes) and
`resolved`.

**H4 - reply**

```bash
glab api --method POST "projects/:fullpath/merge_requests/<iid>/discussions/<discussion-id>/notes" \
  -f body="$(cat reply.md)"
glab mr note <iid> -m "$(cat reply.md)"     # top-level comment
```

**H5 - resolve a discussion**

```bash
glab api --method PUT "projects/:fullpath/merge_requests/<iid>/discussions/<discussion-id>" -f resolved=true
```

**H6 - stacked sub-MR:** branch from the feature branch, push, then
`glab mr create --draft --source-branch "<prefix><ID>--sub-<slug>"
--target-branch "<prefix><ID>" ...`.

**H7 - ready, or back to draft:** `glab mr update <iid> --ready`; back to
draft with `glab mr update <iid> --draft`.

**H8 - approval rules** (Settings > Merge requests; Premium for some):

- Approval rules: at least 1 approval (2 for high-risk paths).
- **Remove all approvals when commits are added to the source branch.**
- Prevent approval by author; prevent approvals by users who add commits.
- Code owner approval for protected branches (`CODEOWNERS` in the root,
  `docs/` or `.gitlab/`).
- Optionally merge trains.

**H9 - MR template:** `.gitlab/merge_request_templates/Default.md` (chosen
by default when named `Default`).

Never: `glab mr merge`, `glab mr approve`, "merge when pipeline succeeds",
or the API equivalents.

## GitLab Issues (tracker)

The feature ID is usually the issue number.

| Action | Command |
|---|---|
| T1 | `glab issue view <n>` (`-F json` for fields) |
| T2 | `glab issue update <n> --assignee <your human partner's username>` and the team's workflow label, for example `--label "workflow::in progress"` |
| T3 | `Closes #<n>` in the MR description of the MR that completes it; `Related to #<n>` in the others |
| T4 | `glab issue note <n> -m "<comment>"` |
| T5 | Closing pattern closes it on merge; otherwise `glab issue close <n>` when your human partner asks |
