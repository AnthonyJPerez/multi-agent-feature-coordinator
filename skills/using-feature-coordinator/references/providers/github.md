# GitHub (code host) and GitHub Issues (tracker)

CLI: `gh`, logged in as your human partner (`gh auth status`). Run commands
from the repo's worktree so `gh` picks the right repository, or pass
`-R owner/repo`. A GitHub MCP server, if connected, can do the same.

## Code host

**H1 - open a draft PR**

```bash
gh pr create --draft --base main --head "<branch>" \
  --title "<ID>: <repo> - <summary>" --body-file "<state>/pr-body.md"
```

Write the body to a file in the feature's state folder (`.feature/<ID>/`)
first; it keeps the decision block intact.

**H2 - PR status, and overlapping PRs**

```bash
gh pr view <n> --json state,isDraft,reviewDecision,mergeStateStatus,headRefOid
gh pr checks <n>
gh pr list --state open --json number,title,headRefName,files \
  --jq '.[] | select(any(.files[]; .path | startswith("api/")))'   # PRs touching api/
```

**H3 - review threads**

```bash
gh api graphql -F owner=OWNER -F repo=REPO -F n=<n> -f query='
query($owner:String!,$repo:String!,$n:Int!){
  repository(owner:$owner,name:$repo){ pullRequest(number:$n){
    reviewThreads(first:100){ nodes{ id isResolved isOutdated path line
      comments(first:50){ nodes{ databaseId author{login} body createdAt } } } } } } }'
gh pr view <n> --comments          # top-level conversation
```

**H4 - reply**

```bash
# reply inside a review thread (comment id = databaseId of a comment in it)
gh api repos/OWNER/REPO/pulls/<n>/comments/<comment-id>/replies -f body="$(cat reply.md)"
# top-level comment
gh pr comment <n> --body-file reply.md
```

**H5 - resolve a thread** (thread `id` from H3)

```bash
gh api graphql -F id=<thread-id> -f query='
mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }'
```

**H6 - stacked sub-PR**

```bash
git switch -c "<prefix><ID>--sub-<slug>" "<prefix><ID>"
git push -u origin HEAD
gh pr create --draft --base "<prefix><ID>" --title "<ID>: <repo> - <sub summary>" --body-file sub-body.md
```

**H7 - ready for review, or back to draft**

```bash
gh pr ready <n>          # draft -> ready for review
gh pr ready <n> --undo   # back to draft
```

GitHub does not request code owners' reviews on a draft; marking it ready
requests them, so they are asked when the PR's merge step comes.

**H8 - approval rules** (repository rulesets or branch protection on the
default branch; an admin sets them):

- Require a pull request with at least 1 approval (2 for high-risk paths via
  a separate ruleset).
- Dismiss stale pull request approvals when new commits are pushed.
- Require approval of the most recent reviewable push.
- Require review from Code Owners (`.github/CODEOWNERS` lists contract,
  auth, billing and CI paths).
- Optionally a merge queue.

**H9 - PR template:** `.github/pull_request_template.md` (or
`.github/PULL_REQUEST_TEMPLATE/<name>.md` for several).

Never: `gh pr merge`, `gh pr review --approve`, `gh pr merge --auto`, or the
REST/GraphQL equivalents.

## GitHub Issues (tracker)

The feature ID is usually the issue number; issues in another repository
are written `owner/repo#123`.

| Action | Command |
|---|---|
| T1 | `gh issue view <n> --json title,body,state,assignees,labels` |
| T2 | `gh issue edit <n> --add-assignee @me` (and the team's "in progress" label or project status, if it uses one) |
| T3 | Put `Closes #<n>` (or `Closes owner/repo#<n>`) in the body of the PR that completes it; `Part of #<n>` in the others |
| T4 | `gh issue comment <n> --body-file note.md` |
| T5 | Closing keywords close it when that PR merges; otherwise `gh issue close <n> --reason completed` if your human partner asks |

GitHub Projects status fields need `gh project item-edit` with project,
item and field IDs; use it only if the team tracks status there.
