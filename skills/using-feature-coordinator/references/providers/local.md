# Local and Self-Hosted Repositories Without Pull Requests

For a repo whose code host is `local` (no remote, or a remote that is a
folder) or `other` (a git server with no pull-request system this plugin
knows: a plain SSH server, Gitolite, cgit, an internal mirror). The work is
the same; review happens through a **review packet** your human partner reads
locally, and your human partner merges.

`fw status` reports these repos from git and the packet: "no commits yet",
"N commit(s), no review packet", "review packet (draft), N commit(s)" (the
packet's status), or "merged into <default branch>".

## Code host actions

**H1 - open a "PR": write the review packet**

1. Write `<state>/reviews/<repo>.md` from the PR template (recording-decisions):
   title `<ID>: <repo> - <summary>`, summary, plan section, Assumptions &
   Autonomous Decisions, Testing, Risk, How to revert. Put `Status: draft` on
   the first line.
2. Add what a reviewer needs to see the change, generated, not retyped:
   ```bash
   git log --oneline <default>..HEAD
   git diff --stat <default>...HEAD
   ```
   Your human partner reads the full diff with `git diff <default>...<branch>`
   in the repo, or you produce patches if they ask:
   `git format-patch <default>..HEAD -o <state>/reviews/<repo>-patches/`.
3. If the repo has a remote that the team reviews branches on (`other`), push
   the branch too (`git push -u origin <branch>`).

**H2 - status:** `fw status <ID>`, plus `git log` / `git diff --stat` as above.

**H3 - review comments:** your human partner gives them in the session, or
writes them to `<state>/reviews/<repo>-comments.md` (one heading per point,
with `file:line`). Read every point before changing anything
(triaging-pr-feedback).

**H4 - reply:** answer under each point in the comments file (or in the
session), with the commit SHA and decision block, as reply-templates.md
shows.

**H5 - resolve:** a point is resolved when your human partner says so; mark
it `Resolved` in the comments file then.

**H6 - stacked sub-change:** branch `<prefix><ID>--sub-<slug>` from the
feature branch, its own packet `<state>/reviews/<repo>--sub-<slug>.md`.
Your human partner merges it into the feature branch.

**H7 - ready for review, or back to draft:** change the packet's first line
to `Status: ready for review` and tell your human partner; `Status: draft`
returns it to draft. Like any other PR, a packet leaves draft only when its
merge step comes.

**H8 - approval rules:** there are none to configure; your human partner is
the approver. For cross-service changes, suggest a second human reads the
packet before merge.

**H9 - template:** `skills/recording-decisions/templates/pull_request_template.md`
in this plugin.

## Merging

Your human partner merges, in the plan's order, in the main checkout:

```bash
git -C <main checkout> merge --no-ff <prefix><ID>
git -C <main checkout> push origin <default>      # if there is a remote
```

The guard blocks you from running these. After the merge, `fw status` shows
"merged into <default>" once the packet exists and the branch has nothing
left to merge, and `fw finish` cleans up.

## Never

- Commit or merge into the default branch, in this worktree or the main
  checkout.
- Email patches (`git send-email`) or post them anywhere unless your human
  partner asks; sending is their call.
