---
name: using-feature-coordinator
description: Use when starting any conversation - establishes when multi-repo feature skills apply, including in coordinator and worker sessions that run inside feature worktrees
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

# Using feature-coordinator

These skills run one feature that spans several repositories. They do not
apply to ordinary single-repo work - for that, carry on as usual.

## How a multi-repo feature runs

- One **coordinator** session works in the anchor repo's feature worktree. It
  writes the spec and the plan with your human partner, locks the
  cross-service contracts, dispatches the workers, verifies across repos and
  writes the briefs. It reads the other repos; it never edits them.
- One **worker** session per repository works in that repo's own feature
  worktree. It implements its slice of the merged plan, owns its pull
  request and answers its review threads.
- Sessions hand off through files: the merged plan and contract copies in
  the anchor repo, plus a mailbox under `.feature/<ID>/`. Nobody works from
  someone else's summary.

## Which skill when

| Situation | Skill |
|---|---|
| A ticket or change touches more than one repo; starting, resuming or checking a multi-repo feature; you are the coordinator | coordinating-multi-repo-features |
| The feature needs its spec | writing-unified-specs |
| The spec is approved; the plan, contracts or rollout order need writing or amending | locking-contracts-with-a-plan |
| The plan is merged and locked; workers need starting or redirecting | dispatching-repo-workers |
| You are a worker in one repo's feature worktree | working-a-repo-slice |
| Review comments arrive on any feature PR | triaging-pr-feedback |
| You made a choice nobody asked for, or are about to push | recording-decisions |
| You are about to claim something works | verifying-with-proof |
| Your human partner asks for status or what happened while away | briefing-your-human-partner |
| Your human partner asks to involve the wider team | asking-the-team |
| PRs are approved or merged; rollout; cleanup | finishing-a-multi-repo-feature |

## Hard rules

1. **Stay in your worktree.** Edit, commit and push only inside the worktree
   this session was started in. Another repo needs a change? Message the
   session that owns it. A hook enforces this; do not work around it.
2. **The merged plan is the contract.** Locked contract files change only
   through a plan amendment that your human partner approves.
3. **Humans merge and approve.** Never merge a PR, approve one, or set one to
   merge itself. An agent's approval never counts.
4. **Triage review feedback; never apply it wholesale.** No `/pr fix
   feedback`, no `/pr auto`, no "address all comments".
5. **Every push carries its decisions.** See recording-decisions.
6. **Tier 3 means stop and ask your human partner** - contracts, auth,
   billing, data migrations, new dependencies, anything irreversible.
7. **Local by default.** Nothing goes to a team channel, a cloud agent or a
   cloud reviewer unless your human partner asks for it.

## Team stack

Which tracker, code host and chat the team uses is configuration, not part
of these skills. Before any step that touches one of them, read the provider
reference for it. Inside a feature worktree your session context lists the
team stack and the reference files; otherwise run the workspace script's
`config` command, and see `references/providers/README.md`.

Each repository has its own code host, and one feature may mix them: GitHub,
Azure DevOps, GitLab, Bitbucket, Gerrit, Gitea, a self-hosted server or a
local repo with no remote. A repo without a pull-request system is reviewed
through a local review packet (`references/providers/local.md`).

In these skills, `fw` stands for `bash <path>/feature-workspace`, the script
in the coordinating-multi-repo-features skill's `scripts/` folder. Your
session context, brief and `fw where` print the absolute path.

## With superpowers

If superpowers is installed, its brainstorming, test-driven development,
debugging, verification and code-review skills still govern engineering
inside a repo. Feature worktrees already exist, so skip its worktree setup;
finish through finishing-a-multi-repo-feature instead of its branch-finishing
skill.

## Platform Adaptation

Skills name actions, not tools. If your harness appears here, read its
reference file:

- Claude Code: `references/claude-code-tools.md`
- GitHub Copilot CLI: `references/copilot-cli-tools.md`
- Codex: `references/codex-tools.md`
- Cursor: `references/cursor-tools.md`
- Gemini CLI: `references/gemini-tools.md`

## User Instructions

Your human partner's instructions and the repository's own instruction files
(CLAUDE.md, AGENTS.md, copilot-instructions.md, GEMINI.md) take precedence
over these skills.
