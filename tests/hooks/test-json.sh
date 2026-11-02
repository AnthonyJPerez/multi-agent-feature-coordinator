#!/usr/bin/env bash
# shellcheck disable=SC2154 # values arrive through printf -v in fc_json_load
# fc_json_load: the payload parser every hook uses. Must agree across awks
# (one-true-awk on macOS, gawk, mawk, busybox) and stay linear on big input.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "JSON payload parsing"
# shellcheck source=../../skills/coordinating-multi-repo-features/scripts/fc-lib
. "$FC_LIB"

BS='\'
json='{"session_id":"s","cwd":"/w/a b","tool_name":"Bash","tool_input":{"command":"echo \"hi\" \\\\ done\nnext\tline '"${BS}u00e9"'","description":"x"},"arr":["bash","-lc","touch \"q\" it'"'"'s"],"empty":"","nested":{"cwd":"/elsewhere"}}'
fc_json_load "$json" J_ cwd tool_name command arr empty missing
assert_eq "plain string" "$J_cwd" "/w/a b"
assert_eq "first occurrence wins" "$J_cwd" "/w/a b"
assert_eq "tool name" "$J_tool_name" "Bash"
assert_eq "escapes decoded" "$J_command" "$(printf 'echo "hi" \\\\ done\nnext\tline ?')"
assert_eq "empty string is set" "${J_empty+set}:$J_empty" "set:"
assert_eq "missing key is unset" "${J_missing+set}" ""
assert_eq "array flag" "${J_arr_array:-}" "1"
assert_eq "array elements" "$J_arr" "$(printf 'bash\004-lc\004touch "q" it'"'"'s')"

escaped='{"content":"text with \"cwd\": \"/fake\" inside","cwd":"/real"}'
fc_json_load "$escaped" E_ cwd
assert_eq "keys inside string values are not keys" "$E_cwd" "/real"

inner='{"toolName":"edit","toolArgs":"{\"path\":\"/x/y\",\"old_str\":\"a\\\\nb\"}"}'
fc_json_load "$inner" C_ toolName toolArgs
fc_json_load "$C_toolArgs" D_ path old_str
assert_eq "JSON inside a JSON string" "$D_path" "/x/y"
assert_eq "double-escaped content" "$D_old_str" 'a\nb'

assert_eq "fc_json_get" "$(fc_json_get "$json" tool_name)" "Bash"
if fc_json_get "$json" nope >/dev/null; then fail "fc_json_get fails for a missing key"; else pass "fc_json_get fails for a missing key"; fi

big=$(python3 -c '
import json
cmd = "cat > f <<EOF\n" + ("line \"q\" \\\\ $x\n" * 20000) + "EOF\n"
print(json.dumps({"cwd": "/w", "tool_name": "Bash", "tool_input": {"command": cmd}}))')
start=$(date +%s)
fc_json_load "$big" B_ cwd command
took=$(($(date +%s) - start))
assert_eq "big payload parsed" "$B_cwd" "/w"
assert_contains "big value intact" "$B_command" 'line "q" \\ $x'
if [ "$took" -le 3 ]; then pass "big payload (${#big} bytes) in ${took}s"; else fail "big payload (${#big} bytes) in ${took}s (limit 3s)"; fi


section "array shapes"
LONG="/private/var/folders/n6/hn37q6pj7sj_9dmqqc2113800000gn/T/fc-test.X5UvQd/guard/ws/svc-b/.worktrees/G-1/q"
GUARD_KEYS="cwd tool_name toolName toolArgs file_path notebook_path path filePath target_file input patch command cmd"
raw() { printf '%s' "$1" | LC_ALL=C awk -v keys="$2" "$FC_JSON_AWK" 2>&1 | tr '\002\003\004' '\\|^'; }
check_array() {  # DESC JSON KEYS EXPECTED_JOINED
  local desc="$1" json="$2" keys="$3" want="$4" got
  # shellcheck disable=SC2086
  fc_json_load "$json" S_ $keys
  got=$(printf '%s' "${S_command-<unset>}" | tr '\004' '^')
  if [ "$got" = "$want" ] && [ "${S_command_array:-}" = 1 ]; then pass "$desc"; else fail "$desc" "got [$got] array=[${S_command_array:-}] raw: $(raw "$json" "$keys")"; fi
}
check_array "nested, short elements" '{"t":{"command":["a","b"]}}' "command" "a^b"
check_array "nested, long element" "{\"t\":{\"command\":[\"bash\",\"-lc\",\"touch $LONG\"]}}" "command" "bash^-lc^touch $LONG"
check_array "top level, long element" "{\"command\":[\"bash\",\"-lc\",\"touch $LONG\"]}" "command" "bash^-lc^touch $LONG"
check_array "top level, short, at the end" '{"command":["a","b"]}' "command" "a^b"
GP="{\"session_id\":\"t\",\"cwd\":\"/private/var/folders/n6/x/T/a/ws/svc-a/.worktrees/G-1\",\"hook_event_name\":\"PreToolUse\",\"tool_name\":\"shell\",\"tool_input\":{\"command\":[\"bash\",\"-lc\",\"touch $LONG\"]}}"
check_array "guard-shaped payload, one key" "$GP" "command" "bash^-lc^touch $LONG"
check_array "guard-shaped payload, guard's keys" "$GP" "$GUARD_KEYS" "bash^-lc^touch $LONG"
check_array "guard's keys, short payload" '{"cwd":"/w","tool_name":"shell","tool_input":{"command":["a","b"]}}' "$GUARD_KEYS" "a^b"
printf '  awk: %s\n' "$(awk --version 2>&1 | head -n 1)"

finish_tests
