# Gitea, Forgejo and Codeberg (code host)

CLI: `tea`, logged in as your human partner (`tea login list`). Run it from
the repo's worktree, or pass `--repo owner/name` (and `--login <name>` when
several servers are configured). The REST API is GitHub-like:
`/api/v1/repos/{owner}/{repo}/pulls/...`. Check `tea pulls --help` if a flag
below is rejected; `tea` moves quickly.

`fw status` shows `n/a (gitea)` for these repos; use H2 below.

## Code host actions

**H1 - open a draft PR.** Gitea marks drafts with a `WIP:` title prefix.

```bash
tea pulls create --head "<branch>" --base main \
  --title "WIP: <ID>: <repo> - <summary>" --description "$(cat "<state>/pr-body.md")"
```

**H2 - status:** `tea pulls list --state all` and `tea pulls <index>`
(state, mergeable, reviews).

**H3 - review comments:** REST
`GET /api/v1/repos/{owner}/{repo}/pulls/{index}/reviews` and, per review,
`.../reviews/{id}/comments` (path and line). `tea pulls <index> --comments`
shows the conversation.

**H4 - reply:** `tea comment <index> "$(cat "<state>/reply.md")"` for the
conversation; inline replies through the web UI or the reviews API.

**H5 - resolve:** leave resolution to the reviewer unless your team lets
authors resolve; the web UI has the button.

**H6 - stacked sub-PR:** `tea pulls create --head "<prefix><ID>--sub-<slug>"
--base "<prefix><ID>" ...`.

**H7 - ready for review, or back to draft:** remove the `WIP:` prefix from
the title (web UI, or `PATCH /api/v1/repos/{owner}/{repo}/pulls/{index}`
with the new `title`); put the prefix back to return it to draft.

**H8 - approval rules** (repository branch protection, set by an admin):
required approvals (1, or 2 for high-risk paths), dismiss stale approvals
when new commits are pushed, block merge on rejected reviews, a
`CODEOWNERS` file (Gitea 1.21+ / Forgejo) for contract and protected paths.

**H9 - PR template:** `.gitea/pull_request_template.md` (Gitea also reads
`.github/pull_request_template.md`).

Never: `tea pulls merge`, `tea pulls approve`, or the API's `/merge` and
approving reviews. The guard blocks the CLI forms and REST merges.
