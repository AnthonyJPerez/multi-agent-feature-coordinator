#!/usr/bin/env bash
# run-hook.cmd: the polyglot dispatcher, Unix side, plus shape checks for the
# Windows side.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "run-hook.cmd"
CMD="$HOOKS_DIR/run-hook.cmd"

mkdir -p "$TEST_ROOT/hooks"
cp "$CMD" "$TEST_ROOT/hooks/run-hook.cmd"
printf '#!/usr/bin/env bash\nprintf "args:%%s\\n" "$*"\nprintf "stdin:%%s\\n" "$(cat)"\nexit 3\n' >"$TEST_ROOT/hooks/probe"

out=$(printf 'payload' | bash "$TEST_ROOT/hooks/run-hook.cmd" probe one two; echo "rc=$?")
assert_contains "runs the named script" "$out" "args:one two"
assert_contains "passes stdin through" "$out" "stdin:payload"
assert_contains "propagates the exit code" "$out" "rc=3"
out=$(cd / && bash "$TEST_ROOT/hooks/run-hook.cmd" probe </dev/null; echo "rc=$?")
assert_contains "works from any directory" "$out" "rc=3"
out=$(env -i /bin/bash "$TEST_ROOT/hooks/run-hook.cmd" probe </dev/null; echo "rc=$?")
assert_contains "works with an empty environment" "$out" "rc=3"

first=$(head -n 1 "$CMD")
assert_eq "first line opens the batch block for bash" "$first" ": << 'CMDBLOCK'"
assert_contains "batch block finds Git for Windows bash" "$(cat "$CMD")" 'C:\Program Files\Git\bin\bash.exe'
if grep -q $'\r' "$CMD"; then fail "LF line endings"; else pass "LF line endings"; fi
assert_contains ".gitattributes pins LF for .cmd" "$(cat "$REPO_ROOT/.gitattributes")" "*.cmd text eol=lf"

if [ -x "$CMD" ]; then pass "run-hook.cmd is executable (harnesses run it directly)"; else fail "run-hook.cmd is executable (harnesses run it directly)"; fi

for h in session-start worktree-guard feature-gate; do
  assert_file "hook script $h exists" "$HOOKS_DIR/$h"
  if bash -n "$HOOKS_DIR/$h"; then pass "$h parses"; else fail "$h parses"; fi
done

finish_tests
