#!/usr/bin/env bash
# feature-gate: Stop hook behavior for workers.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "feature-gate hook"
HOOK="$HOOKS_DIR/feature-gate"

WS=$(make_workspace gate anchor svc)
cd "$WS" || exit 1
fw start S-1 --anchor anchor --repo svc --gate 'svc=test -f ok.txt' >/dev/null 2>&1
W="$WS/svc/.worktrees/S-1"
C="$WS/anchor/.worktrees/S-1"
GATES="$WS/.feature/S-1/gates"

stop() {  # DIR [ENV...] -> stdout + rc line
  local dir="$1"
  shift
  printf '{"session_id":"t","cwd":"%s","hook_event_name":"Stop","stop_hook_active":false}' "$dir" |
    env FC_SESSION_WORKTREE="$dir" "$@" bash "$HOOK" 2>/dev/null
  echo "rc=$?"
}
decision() { printf '%s' "${1%rc=*}" | python3 -c 'import json,sys
t=sys.stdin.read().strip()
print(json.loads(t).get("decision","") if t else "")' 2>/dev/null; }

section "when there is nothing to check"
out=$(stop "$W")
assert_eq "clean worker with no commits stops freely" "$out" "rc=0"
out=$(stop "$C")
assert_eq "coordinator is not gated" "$out" "rc=0"
printf 'x\n' >"$W/change.txt"
out=$(stop "$W" FC_GATE=off)
assert_eq "FC_GATE=off disables" "$out" "rc=0"

section "failing gate"
out=$(stop "$W")
assert_eq "blocks with a decision" "$(decision "$out")" "block"
assert_contains "reason names the gate" "$out" "test -f ok.txt"
assert_contains "reason explains how to stop to ask" "$out" "does not block twice on the same state"
assert_contains "always exits 0" "$out" "rc=0"
assert_file "log written" "$GATES/svc.log"
out=$(stop "$W")
assert_eq "same state: lets the stop through" "$(decision "$out")" ""
assert_contains "same state: tells the human" "$out" "still failing"

section "passing gate"
printf 'ok\n' >"$W/ok.txt"
out=$(stop "$W")
assert_eq "passes once the gate passes" "$out" "rc=0"
assert_file "pass fingerprint" "$GATES/svc.pass"
out=$(stop "$W")
assert_eq "cached pass" "$out" "rc=0"

section "content changes are noticed"
printf 'y\n' >>"$W/change.txt"
rm -f "$W/ok.txt"
out=$(stop "$W")
assert_eq "editing an already-modified file re-runs the gate" "$(decision "$out")" "block"

section "contract drift"
printf 'ok\n' >"$W/ok.txt"
mkdir -p "$C/docs/features/S-1/contracts/svc"
printf 'v1\n' >"$C/docs/features/S-1/contracts/svc/schema.json"
commit_and_push "$C" plan docs
merge_to_main "$WS/anchor" feat/S-1-spec
fw lock S-1 >/dev/null 2>&1
(cd "$W" && fw apply-contract S-1 >/dev/null)
out=$(stop "$W")
assert_eq "matching contracts pass" "$out" "rc=0"
printf 'v2\n' >"$W/schema.json"
out=$(stop "$W")
assert_eq "drift blocks" "$(decision "$out")" "block"
assert_contains "drift reason" "$out" "Contract drift"

section "block limit"
printf 'v1\n' >"$W/schema.json"
out=$(stop "$W")
assert_eq "a pass resets the block count" "$out" "rc=0"
rm -f "$W/ok.txt"
for i in 1 2 3; do
  printf '%s\n' "$i" >>"$W/change.txt"
  out=$(stop "$W")
  assert_eq "block $i of 3" "$(decision "$out")" "block"
done
printf '4\n' >>"$W/change.txt"
out=$(stop "$W")
assert_eq "after three blocks in a row the stop goes through" "$(decision "$out")" ""
assert_contains "and says so" "$out" "after 3 blocked attempts"


section "regressions from review"
regate() { fw start S-1 --anchor anchor --repo svc --gate "svc=$1" >/dev/null 2>&1; }
regate "printf '\\033[31mFAIL\\033[0m colored\\n'; exit 1"
printf 'c1\n' >>"$W/change.txt"
out=$(stop "$W")
body="${out%rc=*}"
if json_ok "$body"; then pass "colored gate output still gives valid JSON"; else fail "colored gate output still gives valid JSON" "$body"; fi
assert_eq "colored failure blocks" "$(decision "$out")" "block"
assert_contains "log tail is readable" "$out" "FAIL colored"

regate "sleep 6; exit 1"
for mode in coreutils portable; do
  printf '%s\n' "$mode" >>"$W/change.txt"
  start=$(date +%s)
  if [ "$mode" = portable ]; then
    out=$(stop "$W" FC_GATE_TIMEOUT=2 FC_GATE_PORTABLE_TIMEOUT=1)
  else
    out=$(stop "$W" FC_GATE_TIMEOUT=2)
  fi
  took=$(($(date +%s) - start))
  if [ "$took" -le 5 ]; then pass "$mode time limit enforced (${took}s)"; else fail "$mode time limit enforced (${took}s)"; fi
  assert_eq "$mode: a timeout does not block" "$(decision "$out")" ""
  assert_contains "$mode: a timeout is reported" "$out" "did not finish within 2s"
  start=$(date +%s)
  out=$(stop "$W" FC_GATE_TIMEOUT=2)
  took=$(($(date +%s) - start))
  if [ "$took" -le 1 ]; then pass "$mode: same state does not rerun the gate"; else fail "$mode: same state does not rerun the gate (${took}s)"; fi
done
# Match whole command lines only, so this test's own shell never counts.
if command -v pgrep >/dev/null 2>&1 && pgrep -f '^(bash -c )?sleep 6(; exit 1)?$' >/dev/null; then
  fail "no gate process left running"
else
  pass "no gate process left running"
fi

regate "exit 1"
cat >"$TEST_ROOT/bin/cygpath" <<EOF
#!/usr/bin/env bash
p="\$2"; p="\${p#C:\\\\fc\\\\}"; p="\${p//\\\\//}"
printf '%s\n' "$WS/\$p"
EOF
chmod +x "$TEST_ROOT/bin/cygpath"
printf 'win\n' >>"$W/change.txt"
out=$(printf '{"cwd":"x","hook_event_name":"Stop"}' | env CLAUDE_PROJECT_DIR='C:\fc\svc\.worktrees\S-1' bash "$HOOK" 2>/dev/null; echo "rc=$?")
assert_eq "Windows project dir still gates the worker" "$(decision "$out")" "block"
rm -f "$TEST_ROOT/bin/cygpath"

finish_tests
