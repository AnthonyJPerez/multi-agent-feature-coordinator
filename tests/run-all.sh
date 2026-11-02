#!/usr/bin/env bash
# Run every test script; exit non-zero if any fails.
set -u
cd "$(dirname "$0")" || exit 1

failed=()
for t in skills/test-skill-structure.sh manifests/test-manifests.sh hooks/test-run-hook-cmd.sh \
  hooks/test-session-start.sh hooks/test-worktree-guard.sh hooks/test-feature-gate.sh \
  workspace/test-feature-workspace.sh shell-lint/test-shell-lint.sh; do
  [ -f "$t" ] || continue
  printf '\n=== %s\n' "$t"
  if [ "${VERBOSE:-0}" = 1 ]; then
    bash "$t" || failed+=("$t")
  else
    out=$(bash "$t" 2>&1)
    rc=$?
    printf '%s\n' "$out" | grep -E '\[FAIL\]|^ {9}' || true
    printf '%s\n' "$out" | tail -n 1
    [ "$rc" -eq 0 ] || failed+=("$t")
  fi
done

printf '\n'
if [ "${#failed[@]}" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "Failed suites: ${failed[*]}"
  exit 1
fi
