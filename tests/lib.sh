# tests/lib.sh - shared helpers for the test scripts. Sourced, not run.
#
# Every test runs against throwaway repositories under a temp directory with
# its own HOME and git config, so nothing touches the real user's setup.

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
FW_SCRIPT="$REPO_ROOT/skills/coordinating-multi-repo-features/scripts/feature-workspace"
FC_LIB="$REPO_ROOT/skills/coordinating-multi-repo-features/scripts/fc-lib"
HOOKS_DIR="$REPO_ROOT/hooks"

PASSES=0
FAILURES=0

pass() {
  PASSES=$((PASSES + 1))
  printf '  [PASS] %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '  [FAIL] %s\n' "$1"
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" | head -n 30 | sed 's/^/         /'; fi
}

section() { printf '\n%s\n' "$1"; }

assert_eq() {  # DESC ACTUAL EXPECTED
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected: $3
actual:   $2"; fi
}

assert_contains() {  # DESC HAYSTACK NEEDLE
  case "$2" in
    *"$3"*) pass "$1" ;;
    *) fail "$1" "missing: $3
in output:
$2" ;;
  esac
}

assert_not_contains() {
  case "$2" in
    *"$3"*) fail "$1" "unexpected: $3
in output:
$2" ;;
    *) pass "$1" ;;
  esac
}

assert_rc() {  # DESC ACTUAL EXPECTED [OUTPUT]
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "exit code $2, expected $3
${4:-}"; fi
}

assert_file() {
  if [ -e "$2" ]; then pass "$1"; else fail "$1" "missing file: $2"; fi
}

assert_no_file() {
  if [ -e "$2" ]; then fail "$1" "file should not exist: $2"; else pass "$1"; fi
}

finish_tests() {
  printf '\n%s passed, %s failed\n' "$PASSES" "$FAILURES"
  [ "$FAILURES" -eq 0 ]
}

# json_ok TEXT - valid JSON?
json_ok() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null
  elif command -v node >/dev/null 2>&1; then
    printf '%s' "$1" | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' 2>/dev/null
  else
    return 0
  fi
}

# json_field TEXT DOTTED.PATH - print a field (python3 required)
json_field() {
  printf '%s' "$1" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for k in sys.argv[1].split("."):
    d = d[int(k)] if isinstance(d, list) else d.get(k) if isinstance(d, dict) else None
    if d is None: break
print("" if d is None else (d if isinstance(d, str) else json.dumps(d)))' "$2"
}

# ---------------------------------------------------------------------------
# sandbox

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/fc-test.XXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd -P)"
cleanup_test_root() { rm -rf "$TEST_ROOT"; }
trap cleanup_test_root EXIT

export HOME="$TEST_ROOT/home"
mkdir -p "$HOME" "$TEST_ROOT/bin"
export GIT_CONFIG_GLOBAL="$TEST_ROOT/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name "Test Engineer"
git config --global user.email "test@example.com"
git config --global init.defaultBranch main
git config --global advice.detachedHead false
unset FC_TRACKER FC_CODE_HOST FC_CHAT FC_BRANCH_PREFIX FC_DOCS_DIR FC_DEFAULT_CLI \
  FC_WORKSPACE FC_SESSION_WORKTREE CLAUDE_PROJECT_DIR CLAUDE_PLUGIN_ROOT COPILOT_CLI \
  CURSOR_PLUGIN_ROOT FC_GUARD FC_GATE 2>/dev/null || true
export PATH="$TEST_ROOT/bin:$PATH"

fw() { bash "$FW_SCRIPT" "$@"; }

# make_workspace NAME REPO... - bare remotes plus clones with one commit on
# main; prints the workspace path
make_workspace() {
  local name="$1" base r
  shift
  base="$TEST_ROOT/$name"
  mkdir -p "$base/remotes" "$base/ws"
  for r in "$@"; do
    git init -q --bare "$base/remotes/$r.git"
    git -C "$base/remotes/$r.git" symbolic-ref HEAD refs/heads/main
    git clone -q "$base/remotes/$r.git" "$base/ws/$r" 2>/dev/null
    printf '# %s\n' "$r" >"$base/ws/$r/README.md"
    git -C "$base/ws/$r" add README.md
    git -C "$base/ws/$r" commit -qm "init $r"
    git -C "$base/ws/$r" push -q origin main 2>/dev/null
    git -C "$base/ws/$r" remote set-head origin -a >/dev/null 2>&1
  done
  printf '%s\n' "$base/ws"
}

# commit_and_push REPO_DIR MESSAGE FILE... - commit files on the current branch and push
commit_and_push() {
  local dir="$1" msg="$2"
  shift 2
  git -C "$dir" add "$@"
  git -C "$dir" commit -qm "$msg"
  git -C "$dir" push -q origin HEAD 2>/dev/null
}

# merge_to_main MAIN_CHECKOUT BRANCH - simulate merging a PR
merge_to_main() {
  git -C "$1" fetch -q origin 2>/dev/null
  git -C "$1" merge -q --no-ff --no-edit "$2" >/dev/null
  git -C "$1" push -q origin main 2>/dev/null
}

# fake_cli NAME HELP_TEXT - a CLI on PATH that prints its help, or its
# arguments (one per line), working directory and session variable
fake_cli() {
  local name="$1" help="$2"
  printf '%s\n' "$help" >"$TEST_ROOT/bin/$name.help"
  cat >"$TEST_ROOT/bin/$name" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "--help" ]; then cat "$TEST_ROOT/bin/$name.help"; exit 0; fi
printf 'PWD=%s\n' "\$PWD"
printf 'FC_SESSION_WORKTREE=%s\n' "\${FC_SESSION_WORKTREE:-}"
printf 'CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=%s\n' "\${CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD:-}"
for a in "\$@"; do printf 'ARG=%s\n' "\$a"; done
EOF
  chmod +x "$TEST_ROOT/bin/$name"
}
