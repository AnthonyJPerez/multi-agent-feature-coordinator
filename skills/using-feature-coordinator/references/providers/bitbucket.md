# Bitbucket Cloud (code host)

Bitbucket has no official CLI. Use the Atlassian (Rovo) MCP server if your
human partner has it connected; otherwise the REST API with `curl`, with an
API token your human partner exported (for example `BITBUCKET_USER` and
`BITBUCKET_TOKEN`) - never write it into a file or echo it. Bitbucket Data
Center's API differs; check your edition's docs before using these.

`fw status` shows `n/a` for Bitbucket PRs; check them here.

```bash
BB="https://api.bitbucket.org/2.0/repositories/<workspace>/<repo>"
AUTH=(-u "$BITBUCKET_USER:$BITBUCKET_TOKEN")
```

**H1 - open a draft PR**

```bash
curl -sS "${AUTH[@]}" -H 'Content-Type: application/json' -X POST "$BB/pullrequests" \
  --data @pr.json   # {"title": "...", "description": "...", "draft": true,
                    #  "source": {"branch": {"name": "<branch>"}},
                    #  "destination": {"branch": {"name": "main"}}}
```

**H2 - status:** `curl -sS "${AUTH[@]}" "$BB/pullrequests/<id>"` (state,
draft, participants with `approved`), and `.../pullrequests/<id>/statuses`
for builds.

**H3 - comments:** `curl -sS "${AUTH[@]}" "$BB/pullrequests/<id>/comments"`
(inline comments carry `inline.path` and `inline.to`; replies carry
`parent.id`).

**H4 - reply:** POST to `$BB/pullrequests/<id>/comments` with
`{"content": {"raw": "..."}, "parent": {"id": <comment-id>}}`.

**H5 - resolve:** POST `$BB/pullrequests/<id>/comments/<comment-id>/resolve`
(verify it is available on your plan; otherwise leave threads to the
reviewer).

**H6 - stacked sub-PR:** as H1 with the feature branch as `destination`.

**H7 - ready:** PUT `$BB/pullrequests/<id>` with `{"draft": false}`.

**H8 - approval rules** (Repository settings > Branch restrictions / merge
checks; some need Premium): minimum approvals, reset approvals when the
source branch changes, default reviewers for contract and protected paths.

**H9 - PR template:** Bitbucket Cloud uses a default description set in
repository settings rather than a file; paste the PR template there.

Jira links itself to Bitbucket through the issue key in branch names,
commits and PR titles.

Never merge, approve, or enable auto-merge through any route.
