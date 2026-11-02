#!/usr/bin/env bash
# session-start: one output field per harness, valid JSON, bootstrap content,
# feature context inside a feature worktree only.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "session-start hook"
HOOK="$HOOKS_DIR/session-start"

run_hook() {  # ENV... -> stdout (stderr discarded); runs from $RUN_DIR
  (cd "${RUN_DIR:-$TEST_ROOT}" && env -i PATH="$PATH" HOME="$HOME" GIT_CONFIG_GLOBAL="$GIT_CONFIG_GLOBAL" "$@" bash "$HOOK" 2>/dev/null)
}

section "output shape per harness"
out=$(run_hook CLAUDE_PLUGIN_ROOT="$REPO_ROOT")
if json_ok "$out"; then pass "Claude Code output is valid JSON"; else fail "Claude Code output is valid JSON" "$out"; fi
ctx=$(json_field "$out" hookSpecificOutput.additionalContext)
assert_eq "Claude Code event name" "$(json_field "$out" hookSpecificOutput.hookEventName)" "SessionStart"
assert_contains "Claude Code: bootstrap injected" "$ctx" "You have feature-coordinator skills."
assert_contains "Claude Code: skill body included" "$ctx" "# Using feature-coordinator"
assert_contains "Claude Code: wrapped" "$ctx" "</EXTREMELY_IMPORTANT>"
assert_eq "Claude Code: no top-level additionalContext" "$(json_field "$out" additionalContext)" ""
assert_not_contains "Claude Code: no additional_context" "$out" "additional_context"

out=$(run_hook CLAUDE_PLUGIN_ROOT="$REPO_ROOT" COPILOT_CLI=1)
if json_ok "$out"; then pass "Copilot output is valid JSON"; else fail "Copilot output is valid JSON" "$out"; fi
assert_contains "Copilot: top-level additionalContext" "$(json_field "$out" additionalContext)" "You have feature-coordinator skills."
assert_not_contains "Copilot: no hookSpecificOutput" "$out" "hookSpecificOutput"

out=$(run_hook CURSOR_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PLUGIN_ROOT="$REPO_ROOT")
if json_ok "$out"; then pass "Cursor output is valid JSON"; else fail "Cursor output is valid JSON" "$out"; fi
assert_contains "Cursor: additional_context" "$(json_field "$out" additional_context)" "You have feature-coordinator skills."
assert_not_contains "Cursor: no hookSpecificOutput" "$out" "hookSpecificOutput"

out=$(run_hook)
assert_contains "unknown harness: SDK-standard field" "$(json_field "$out" additionalContext)" "feature-coordinator"

section "feature context"
out=$(run_hook CLAUDE_PLUGIN_ROOT="$REPO_ROOT")
assert_not_contains "no feature context outside a worktree" "$out" "feature-context"

WS=$(make_workspace ss anchor svc)
(cd "$WS" && printf 'tracker = azure-boards\nchat = teams\n' >anchor/.feature-coordinator.conf &&
  commit_and_push anchor conf .feature-coordinator.conf &&
  fw start F-9 --anchor anchor --repo svc >/dev/null 2>&1)
WT="$WS/svc/.worktrees/F-9"
out=$(RUN_DIR="$WT" run_hook CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CLAUDE_PROJECT_DIR="$WT")
if json_ok "$out"; then pass "feature output is valid JSON"; else fail "feature output is valid JSON" "$out"; fi
ctx=$(json_field "$out" hookSpecificOutput.additionalContext)
assert_contains "names the worker role" "$ctx" "WORKER session for svc in feature F-9"
assert_contains "gives the worktree" "$ctx" "Worktree (edit only here): $WT"
assert_contains "points at the brief" "$ctx" "briefs/worker-svc.md"
assert_contains "lists the tracker reference" "$ctx" "providers/azure-devops.md"
assert_contains "lists the chat reference" "$ctx" "providers/teams.md"
assert_contains "mail command" "$ctx" "mail F-9 inbox --for svc"

out=$(RUN_DIR="$TEST_ROOT" run_hook CLAUDE_PLUGIN_ROOT="$REPO_ROOT" FC_SESSION_WORKTREE="$WS/anchor/.worktrees/F-9")
ctx=$(json_field "$out" hookSpecificOutput.additionalContext)
assert_contains "FC_SESSION_WORKTREE identifies the coordinator" "$ctx" "COORDINATOR session for feature F-9"

section "robustness"
out=$(cd "$TEST_ROOT" && env -i PATH="$PATH" HOME="$HOME" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOK" </dev/null; echo "rc=$?")
assert_contains "exits 0" "$out" "rc=0"
out=$(env -i /bin/bash "$HOOKS_DIR/run-hook.cmd" session-start 2>/dev/null)
if json_ok "$out"; then pass "run-hook.cmd works with an empty environment"; else fail "run-hook.cmd works with an empty environment" "$out"; fi
for f in "$HOOKS_DIR/session-start" "$HOOKS_DIR/worktree-guard" "$HOOKS_DIR/feature-gate" "$FC_LIB"; do
  if grep -q '<<' "$f"; then fail "no heredocs or here-strings in $(basename "$f") (bash 5.3 hang)"
  else pass "no heredocs or here-strings in $(basename "$f") (bash 5.3 hang)"; fi
done

finish_tests
