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

finish_tests
