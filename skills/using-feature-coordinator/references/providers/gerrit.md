# Gerrit (code host)

Gerrit reviews **changes** (one commit each, identified by a `Change-Id`
trailer) instead of branches. Use the Gerrit MCP server if your human
partner has one; otherwise `git push` plus Gerrit's SSH commands
(`ssh -p 29418 <host> gerrit ...`) or its REST API, as your human partner's
own identity. Replace `<host>` with the Gerrit server and `<default>` with the
target branch.

Setup once per repo (your human partner, not you - it writes into the main
checkout's git directory): the `commit-msg` hook that adds `Change-Id`
(`https://<host>/tools/hooks/commit-msg` into the repo's `hooks` folder).

**Use the feature ID as the Gerrit topic.** Every change for the feature, in
every repo on that server, then shows up together in one query.

## Code host actions

**H1 - upload a change (work in progress)**

```bash
git push origin HEAD:refs/for/<default>%topic=<ID>,wip
```

Squash your work into one commit per reviewable change, with the PR
template's sections in the commit message body (Gerrit shows the commit
message as the description). Amend the same commit (keep its `Change-Id`) to
upload a new patch set.

**H2 - status:**
```bash
ssh -p 29418 <host> gerrit query --format=JSON --current-patch-set topic:<ID>
```
Look at `status` (NEW, MERGED, ABANDONED), `wip` and the label votes.

**H3 - review comments:**
```bash
ssh -p 29418 <host> gerrit query --format=JSON --comments --current-patch-set change:<number>
```
or REST `GET /changes/<number>/comments` for inline comments with file and
line.

**H4 - reply:** `ssh -p 29418 <host> gerrit review <number>,<patchset> --message "$(cat <state>/reply.md)"`
(inline replies go through REST `POST /changes/<number>/revisions/current/review`
with `comments`, and no `labels`).

**H5 - resolve:** reply to the comment with `"unresolved": false` in that
REST review call, or leave it to the reviewer.

**H6 - stacked change:** commit on top of your change; Gerrit uploads both and
shows the dependency. Keep each change reviewable on its own.

**H7 - ready for review:** `git push origin HEAD:refs/for/<default>%ready`

**H8 - approval rules** (project access and submit requirements, set by an
admin): `Code-Review +2` from a human with that right, `Verified +1` from CI,
code owners (plugin) for contract and protected paths. Agents never vote
`+2` and never submit.

**H9 - template:** the commit message body carries the PR template's
sections.

Never: `gerrit review --submit`, `gerrit submit`, `%submit` on push,
`Code-Review +2` from your session, or REST `.../submit`. The guard blocks
the common forms.

`fw status` shows `n/a (gerrit)` for these repos; use the topic query above.
Changes submitted by rebase or cherry-pick still count as merged for
`fw finish`, which compares patches, not commit ids.
