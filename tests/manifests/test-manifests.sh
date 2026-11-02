#!/usr/bin/env bash
# Manifests for every ecosystem: valid JSON, consistent names and versions,
# and every path they reference exists.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "manifests"
cd "$REPO_ROOT" || exit 1

field() { python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."):
    d = d[int(k)] if isinstance(d, list) else d.get(k) if isinstance(d, dict) else None
print("" if d is None else (d if isinstance(d,str) else json.dumps(d)))' "$1" "$2"; }

for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json .codex-plugin/plugin.json \
  .agents/plugins/marketplace.json .cursor-plugin/plugin.json gemini-extension.json \
  hooks/hooks.json hooks/hooks-cursor.json .version-bump.json; do
  if json_ok "$(cat "$f")"; then pass "$f is valid JSON"; else fail "$f is valid JSON"; fi
done

section "names and versions"
v=$(field .claude-plugin/plugin.json version)
for spec in ".claude-plugin/plugin.json:name" ".codex-plugin/plugin.json:name" ".cursor-plugin/plugin.json:name" \
  "gemini-extension.json:name" ".claude-plugin/marketplace.json:plugins.0.name" ".agents/plugins/marketplace.json:plugins.0.name"; do
  assert_eq "${spec%%:*} ${spec#*:}" "$(field "${spec%%:*}" "${spec#*:}")" "feature-coordinator"
done
for spec in $(python3 -c 'import json; [print(f"{e[\"path\"]}:{e[\"field\"]}") for e in json.load(open(".version-bump.json"))["files"]]'); do
  assert_eq "version in ${spec%%:*}" "$(field "${spec%%:*}" "${spec#*:}")" "$v"
done

section "paths"
assert_eq "Claude marketplace source is the repo" "$(field .claude-plugin/marketplace.json plugins.0.source)" "./"
assert_eq "Codex manifest points at skills" "$(field .codex-plugin/plugin.json skills)" "./skills/"
assert_eq "Codex manifest suppresses hooks" "$(field .codex-plugin/plugin.json hooks)" "{}"
assert_eq "Cursor skills" "$(field .cursor-plugin/plugin.json skills)" "./skills/"
assert_file "Cursor hooks file" "$(field .cursor-plugin/plugin.json hooks)"
assert_file "Gemini context file" "$(field gemini-extension.json contextFileName)"
while IFS= read -r inc; do assert_file "GEMINI.md include $inc" "${inc#@}"; done <GEMINI.md

section "hook commands"
cmds=$(python3 -c 'import json
d=json.load(open("hooks/hooks.json"))["hooks"]
for ev, groups in d.items():
    for g in groups:
        for h in g["hooks"]:
            print(ev + "\t" + h["command"])')
for ev in SessionStart PreToolUse Stop; do
  assert_contains "hooks.json has $ev" "$cmds" "$ev"
done
while IFS=$'\t' read -r ev cmd; do
  script="${cmd##* }"
  assert_contains "$ev uses the dispatcher" "$cmd" '${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd'
  assert_file "$ev script exists" "hooks/$script"
done <<<"$cmds"
assert_eq "SessionStart matcher" "$(field hooks/hooks.json hooks.SessionStart.0.matcher)" "startup|clear|compact"
assert_contains "Cursor hook command" "$(field hooks/hooks-cursor.json hooks.sessionStart.0.command)" "./hooks/run-hook.cmd session-start"

section "Claude Code validation"
if command -v claude >/dev/null 2>&1 && claude plugin validate --help >/dev/null 2>&1; then
  out=$(claude plugin validate . --strict 2>&1); rc=$?
  assert_rc "claude plugin validate --strict" "$rc" 0 "$out"
else
  pass "claude CLI not installed - skipped validate"
fi

finish_tests
