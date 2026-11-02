#!/usr/bin/env bash
# Shell scripts: parse, avoid bash 4+ features (macOS ships bash 3.2), and
# pass shellcheck when it is installed.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "shell lint"
cd "$REPO_ROOT" || exit 1

scripts=(
  skills/coordinating-multi-repo-features/scripts/feature-workspace
  skills/coordinating-multi-repo-features/scripts/fc-lib
  hooks/session-start
  hooks/worktree-guard
  hooks/feature-gate
  scripts/bump-version.sh
)

for s in "${scripts[@]}"; do
  if bash -n "$s" 2>/dev/null; then pass "$s parses"; else fail "$s parses"; fi
done

section "bash 3.2 compatibility (runtime scripts)"
runtime=("${scripts[@]:0:5}")
for s in "${runtime[@]}"; do
  bad=$(grep -nE 'declare -A|local -A|mapfile|readarray|\$\{[A-Za-z_][A-Za-z0-9_]*(,,|\^\^)\}|\[-1\]|coproc |local -n |declare -n ' "$s" | grep -vE '^[0-9]+:[[:space:]]*#' || true)
  if [ -z "$bad" ]; then pass "$s avoids bash 4+ features"; else fail "$s avoids bash 4+ features" "$bad"; fi
done

section "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  for s in "${scripts[@]}"; do
    out=$(shellcheck -x -s bash -S warning -e SC1090,SC1091,SC2034 "$s" 2>&1)
    if [ -z "$out" ]; then pass "shellcheck $s"; else fail "shellcheck $s" "$out"; fi
  done
else
  pass "shellcheck not installed - skipped"
fi

finish_tests
