# {{ID}}: {{Feature name}} - Specification

- Work item: {{link}}
- Owner: {{engineer}}
- Repositories: {{anchor}}, {{repo-a}}, {{repo-b}}
- Status: draft | approved

## Problem

Who has the problem, what it costs them today, and what evidence we have.

## Goals

- ...

## Non-goals

- ...

## Behavior

One subsection per scenario. For each: the trigger, what the user or caller
sees, and what each service does.

### Scenario: {{name}}

1. ...

## Services and Boundaries

| Repository | Responsibility in this feature |
|---|---|
| {{repo}} | ... |

How the services talk (sequence or bullet flow). Which calls are new, which
change.

## Data and Contract Changes (conceptual)

What new or changed data crosses a service boundary, in words. Exact
schemas go in the plan.

## Rollout

Feature flags, who sees it first, how it is turned off, compatibility with
older clients during rollout.

## Failure Modes

What happens when each dependency is slow, down or returns errors.

## Security and Privacy

Authentication, authorization, personal data, audit needs.

## Data Migration

Existing data that must change, and whether the change can be undone.

## Acceptance Criteria

Testable statements; each one names the scenario it covers.

- [ ] AC1: ...

## Open Questions

- ...
