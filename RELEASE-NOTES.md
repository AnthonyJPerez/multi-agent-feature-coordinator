# Release Notes

## Unreleased

- Pull requests open as drafts and stay drafts until their merge step in the
  plan comes. Workers open the draft at their first push, so reviewers can
  comment while the work happens, and triage those comments as they arrive;
  when the slice is done they report it complete instead of marking it
  ready. The coordinator marks the current merge step's complete PRs ready
  (on Azure DevOps: publishes them), one step at a time, and returns a PR
  that needs a large change to draft. Workers still mark their own stacked
  sub-PRs ready.
- Provider references cover both directions of H7, ready and back to draft,
  for GitHub, Azure DevOps, GitLab, Bitbucket, Gerrit, Gitea and review
  packets, plus how each host treats drafts.
- `fw status` shows whether GitLab merge requests and review packets are
  drafts.
- The README leads with the problem, the approach and when to use the
  plugin, with a diagram of the sessions, repos and hosts.

## 0.1.0 - 2026-11-01

First release.

- Twelve skills covering the multi-repo feature lifecycle: coordination,
  unified spec, contract-locking plan, worker dispatch, per-repo
  implementation, PR feedback triage, decision recording, verification with
  proof, briefs, asking the team, and finishing.
- `feature-workspace` CLI: correlated worktrees, configurable team stack,
  contract lock by git blob id, file mailbox, decision log, status across
  GitHub / Azure Repos / GitLab, launch commands for Claude Code, Copilot
  CLI and Codex (printed or in tmux), and guarded cleanup.
- Hooks: session-start context (bootstrap, role, documents, team stack),
  worktree guard (file edits and common shell writes, force and
  default-branch pushes, merges, approvals and auto-complete on every
  supported host, contract unlocks, protected paths), Stop gate (contract
  check and per-repo gate command, once per worktree state).
- Local-first, any git host: one feature can mix repos on GitHub, Azure
  DevOps Services or Server, GitLab, Bitbucket, Gerrit, Gitea/Forgejo, any
  self-hosted git server and local repos with no remote. The host is
  detected per repo or set with `code_host.<repo>`; repos without pull
  requests are reviewed through a local review packet.
- Configurable stack: Azure Boards, Jira, GitHub Issues, Linear or GitLab
  Issues; Teams, Slack or Discord; branch prefix, docs folder, gates,
  models, protected paths.
- Manifests for Claude Code, GitHub Copilot CLI, Codex, Cursor and Gemini
  CLI.
