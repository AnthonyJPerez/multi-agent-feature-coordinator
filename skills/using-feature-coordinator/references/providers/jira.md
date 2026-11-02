# Jira (tracker)

Use the Atlassian (Rovo) MCP server if your human partner has it connected.
Otherwise the Atlassian CLI, `acli`, logged in as your human partner
(`acli jira auth status`). Check `acli jira workitem <command> --help` if a
flag below is rejected - the CLI is young and still changing.

The feature ID is the Jira key (`PAY-42`). Because branch names carry it
(`<prefix>PAY-42`), Jira's development panel links branches, commits and
PRs automatically once the team's code host is connected to Jira (GitHub for
Jira, GitLab for Jira Cloud, Bitbucket natively; Azure DevOps through its
Jira integration).

| Action | Command |
|---|---|
| T1 | `acli jira workitem view PAY-42` (add `--json` for fields) |
| T2 | `acli jira workitem assign --key PAY-42 --assignee "@me"` then `acli jira workitem transition --key PAY-42 --status "In Progress" --yes` |
| T3 | Put the key in the PR title (`PAY-42: billing-service - ...`); the integration links it. No command needed. |
| T4 | `acli jira workitem comment create --key PAY-42 --body-file note.md` |
| T5 | `acli jira workitem transition --key PAY-42 --status "Done" --yes` - only when your human partner asks, or let the team's automation move it on merge |

Status names ("In Progress", "In Review", "Done") are per workflow; ask
your human partner once and use theirs.

Searching for related work, for overlap checks:

```bash
acli jira workitem search --jql 'project = PAY AND statusCategory != Done AND text ~ "invoice"' --json
```
