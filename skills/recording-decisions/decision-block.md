# Decision Block

Paste into the PR description (first push) or a PR comment / thread reply
(later pushes). One entry per decision; newest first.

```markdown
### Assumptions & Autonomous Decisions

- **Decision:** <what was chosen, one line>
  - **Why:** <reason>
  - **Alternatives:** <what else was possible>
  - **Tier:** 2 | 3 (approved by <name> on <date>)
  - **Reversible by:** <how to undo, if not obvious>

- **Assumption:** <what was assumed because nothing said otherwise>
  - **Based on:** <spec/plan section, code, convention>
  - **If wrong:** <what would need to change>
```

No new decisions in this push:

```markdown
### Assumptions & Autonomous Decisions

No new autonomous decisions in <sha>.
```
