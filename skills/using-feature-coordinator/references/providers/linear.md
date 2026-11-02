# Linear (tracker)

Use Linear's official remote MCP server (hosted at `mcp.linear.app`; your
human partner connects it once and signs in through the browser). There is
no official Linear CLI; without the MCP server, your human partner updates
Linear by hand and you give them the text.

The feature ID is the Linear issue ID (`ENG-123`). Linear's GitHub and
GitLab integrations link any branch, commit or PR whose name or title
contains the ID, and can move the issue through In Progress / In Review /
Done automatically, depending on the team's workflow settings.

| Action | How |
|---|---|
| T1 | MCP: get issue `ENG-123` (title, description, state, assignee) |
| T2 | MCP: assign to your human partner and set the in-progress state - or let the integration do it when the branch is pushed |
| T3 | Branch `<prefix>ENG-123` and the ID in the PR title; `Fixes ENG-123` in the PR that completes it, `Part of ENG-123` in the others |
| T4 | MCP: add a comment |
| T5 | The closing magic word moves it on merge; otherwise MCP: set the done state when your human partner asks |
