#!/usr/bin/env bash
# Run every test script; exit non-zero if any fails.
#
#   VERBOSE=1       stream every assertion as it runs (CI does this)
#   SUITE_TIMEOUT   seconds before a hanging suite is killed (default 600)
set -u
cd "$(dirname "$0")" || exit 1

limit="${SUITE_TIMEOUT:-600}"

# with_limit CMD... - run CMD, killed after $limit seconds (exit 124/142)
with_limit() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$limit" "$@"
  elif command -v perl >/dev/null 2>&1; then
    # macOS has no coreutils timeout. Run the suite in its own process group
    # and kill the whole group, hooks included, when the alarm fires.
    perl -e '
      my $t = shift;
      my $pid = fork();
      die "fork: $!" unless defined $pid;
      if ($pid == 0) { setpgrp(0, 0); exec @ARGV or die "exec: $!"; }
      $SIG{ALRM} = sub { kill "TERM", -$pid; sleep 2; kill "KILL", -$pid; exit 124; };
      alarm $t;
      waitpid($pid, 0);
      exit($? & 127 ? 128 + ($? & 127) : $? >> 8);
    ' "$limit" "$@"
  else
    "$@"
  fi
}

failed=()
for t in skills/test-skill-structure.sh manifests/test-manifests.sh hooks/test-json.sh hooks/test-run-hook-cmd.sh \
  hooks/test-session-start.sh hooks/test-worktree-guard.sh hooks/test-feature-gate.sh \
  workspace/test-feature-workspace.sh shell-lint/test-bash-constructs.sh shell-lint/test-shell-lint.sh; do
  [ -f "$t" ] || continue
  printf '\n=== %s\n' "$t"
  start=$(date +%s)
  if [ "${VERBOSE:-0}" = 1 ]; then
    with_limit bash "$t" </dev/null
    rc=$?
  else
    out=$(with_limit bash "$t" </dev/null 2>&1)
    rc=$?
    printf '%s\n' "$out" | grep -E '\[FAIL\]|^ {9}' || true
    printf '%s\n' "$out" | tail -n 1
  fi
  took=$(($(date +%s) - start))
  case "$rc" in
    0) printf '(%ss)\n' "$took" ;;
    124 | 142) printf 'TIMED OUT after %ss\n' "$took"; failed+=("$t (timeout)") ;;
    *) failed+=("$t") ;;
  esac
done

printf '\n'
if [ "${#failed[@]}" -eq 0 ]; then
  echo "All test suites passed."
else
  echo "Failed suites: ${failed[*]}"
  exit 1
fi
