# {{ID}}: {{Feature name}} - Implementation Plan

- Spec: `spec.md` (merged in {{spec PR link}})
- Owner: {{engineer}}
- Status: draft | merged (contract lock)

## PR Matrix

| # | Repository | Branch | Depends on | Merge order | Flag |
|---|---|---|---|---|---|
| 1 | {{repo}} | `{{prefix}}{{ID}}` | - | 1 | `{{flag}}` |
| 2 | {{repo}} | `{{prefix}}{{ID}}` | #1 | 2 | `{{flag}}` |
| D | {{anchor}} | `{{prefix}}{{ID}}-docs` | all | last | - |

## Compatibility Rule

Expand, then contract. Each PR is safe to merge before the PRs after it:
new fields and endpoints are additive; callers switch behind flags; removal
of the old shape is its own later PR.

## Contracts

| Repository | File in repo | Locked copy |
|---|---|---|
| {{repo}} | `api/openapi.yaml` | `contracts/{{repo}}/api/openapi.yaml` |

Breaking-change check: {{command and result}}

## Repository Sections

### {{repo}}

- **Changes:** ...
- **Touches:** modules or files
- **Acceptance tests:** (each tied to a spec criterion)
  - [ ] AT-{{repo}}-1 (AC1): ...
- **Gate:** `{{command}}` (if not set in the team config)
- **Notes for the worker:** ...

## Flags and Rollout

| Order | Flag | Repository | Turn on when | Turn off by |
|---|---|---|---|---|
| 1 | `{{flag}}` | {{repo}} | ... | ... |

## Cross-Repo End-to-End Check

How the coordinator proves the whole feature works locally (services to
start, scenario to run, evidence to capture).

## Decisions

| Date | Decision | Why | Alternatives |
|---|---|---|---|

## Amendments

(Dated entries added by amendment PRs.)
