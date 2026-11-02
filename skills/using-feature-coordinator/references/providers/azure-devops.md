# Azure DevOps: Azure Repos (code host) and Azure Boards (tracker)

CLI: `az` with the `azure-devops` extension (`az extension add --name
azure-devops`), logged in as your human partner (`az login`). Set defaults
once so commands stay short:

```bash
az devops configure --defaults organization=https://dev.azure.com/<org> project=<project>
```

The Azure DevOps MCP server, if connected, covers the same actions and is
easier for review threads.

`fw status` derives organization, project and repository from each repo's
`origin` URL.

## Azure Repos (code host)

**H1 - open a draft PR**

```bash
az repos pr create --repository <repo> \
  --source-branch "<branch>" --target-branch main \
  --title "<ID>: <repo> - <summary>" \
  --description "$(cat "<state>/pr-body.md")" \
  --work-items <work-item-id> --draft true
```

**H2 - status and overlapping PRs**

```bash
az repos pr show --id <pr> --query "{status:status,isDraft:isDraft,mergeStatus:mergeStatus,reviewers:reviewers[].{name:displayName,vote:vote}}"
az repos pr policy list --id <pr> -o table          # build, reviewer and work item policies
az repos pr list --repository <repo> --status active -o table
```

Votes: 10 approved, 5 approved with suggestions, 0 none, -5 waiting, -10
rejected.

**H3 / H4 / H5 - review threads.** The `az repos pr` group has no thread
commands; use the REST API through `az devops invoke` (or `az rest`, or the
MCP server):

```bash
# H3: list threads (status, file path and line are in threadContext)
az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<pr> \
  --api-version 7.1 --http-method GET

# H4: reply in thread <tid> (jq JSON-encodes the reply text)
printf '{"content": %s, "parentCommentId": 1, "commentType": 1}' "$(jq -Rs . < "<state>/reply.md")" > "<state>/reply.json"
az devops invoke --area git --resource pullRequestThreadComments \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<pr> threadId=<tid> \
  --api-version 7.1 --http-method POST --in-file "<state>/reply.json"

# H5: resolve thread <tid>
printf '{"status": "fixed"}' > "<state>/status.json"
az devops invoke --area git --resource pullRequestThreads \
  --route-parameters project=<project> repositoryId=<repo> pullRequestId=<pr> threadId=<tid> \
  --api-version 7.1 --http-method PATCH --in-file "<state>/status.json"
```

The REST paths behind these are
`_apis/git/repositories/{repo}/pullRequests/{pr}/threads[/{tid}[/comments]]`.
If a route parameter name is rejected, `az devops invoke --help` and the
REST reference give the current names. New top-level comment: POST to
`pullRequestThreads` with `{"comments": [{"content": "...", "commentType": 1}], "status": "active"}`.

**H6 - stacked sub-PR:** create the branch from the feature branch, push it,
then `az repos pr create ... --source-branch "<prefix><ID>--sub-<slug>"
--target-branch "<prefix><ID>" --draft true`.

**H7 - ready for review:** `az repos pr update --id <pr> --draft false`

**H8 - approval rules** (Project settings > Repositories > Policies on the
default branch; an admin sets them):

- Require a minimum number of reviewers: 1 (2 for high-risk paths).
- **Prohibit the most recent pusher from approving their own changes.**
- **When new changes are pushed: reset all approval votes.**
- Do not allow requestors to approve their own changes.
- Automatically included reviewers with path filters for contract, auth,
  billing and pipeline paths (Azure Repos' equivalent of code owners).
- Check for linked work items; check for comment resolution.

**H9 - PR template:** `.azuredevops/pull_request_template.md` (also accepted
in `.vsts/`, `docs/` or the repo root; branch-specific templates go in
`.azuredevops/pull_request_template/branches/<branch>.md`).

Never: `az repos pr update --status completed`, `--auto-complete true`,
`az repos pr set-vote --vote approve`, or the REST equivalents.

## Azure Boards (tracker)

The feature ID is the work item number (for example `4711`).

| Action | Command |
|---|---|
| T1 | `az boards work-item show --id <id> --fields "System.Title,System.State,System.Description,Microsoft.VSTS.Common.AcceptanceCriteria"` |
| T2 | `az boards work-item update --id <id> --state "Active" --assigned-to "<your human partner's email>"` (the "in progress" state name depends on the process: Active, Doing, In Progress, Committed) |
| T3 | `--work-items <id>` on `az repos pr create`, or `az repos pr work-item add --id <pr> --work-items <id>`. For code on GitHub, write `AB#<id>` in the PR description or commit message. |
| T4 | `az boards work-item update --id <id> --discussion "<comment>"` |
| T5 | Azure Repos can complete linked work items when the PR completes (an option on completion, chosen by whoever merges); otherwise `az boards work-item update --id <id> --state "Closed"` when your human partner asks |

Ask your human partner for the exact state names once; they are process
specific.
