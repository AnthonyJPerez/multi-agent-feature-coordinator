#!/usr/bin/env bash
# worktree-guard: deny/allow matrix for Claude Code and Copilot payloads.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "worktree-guard hook"
HOOK="$HOOKS_DIR/worktree-guard"

WS=$(make_workspace guard anchor svc-a svc-b)
cd "$WS" || exit 1
printf 'protected_paths = **/auth/**, package.json\n' >anchor/.feature-coordinator.conf
commit_and_push anchor conf .feature-coordinator.conf
fw start G-1 --anchor anchor --repo svc-a --repo svc-b >/dev/null 2>&1
A="$WS/svc-a/.worktrees/G-1"
B="$WS/svc-b/.worktrees/G-1"
C="$WS/anchor/.worktrees/G-1"
STATE="$WS/.feature/G-1"
git init -q "$WS/unrelated"

# contracts: lock one file for svc-a
mkdir -p "$C/docs/features/G-1/contracts/svc-a/api"
printf 'openapi: 3.1.0\n' >"$C/docs/features/G-1/contracts/svc-a/api/openapi.yaml"
commit_and_push "$C" plan docs
merge_to_main "$WS/anchor" feat/G-1-spec
fw lock G-1 >/dev/null 2>&1

json_escape() { printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }

# Build payloads with obj (or in a variable), never as "{\"k\":\"v\",...}"
# literals inside "$(...)": bash 3.2 brace-expands those, running the command
# once per key (see AGENTS.md). A malformed payload makes the guard fail
# open, which would let an "expect 0" test pass for the wrong reason, so the
# helpers refuse to send one.
obj() {  # KEY VALUE ... -> JSON object of strings
  python3 -c 'import json,sys; a=sys.argv[1:]; print(json.dumps(dict(zip(a[::2], a[1::2]))))' "$@"
}
valid_json() { python3 -c 'import json,sys; json.loads(sys.argv[1])' "$1" 2>/dev/null; }
bad_input() {
  printf 'test bug: input is not valid JSON: %s\n' "$1" >"$TEST_ROOT/guard.err"
  echo "rc=bad-input"
}

# claude WHO_DIR TOOL INPUT_JSON [EXTRA_ENV...]
claude() {
  local dir="$1" tool="$2" input="$3"
  shift 3
  valid_json "$input" || { bad_input "$input"; return; }
  printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' \
    "$dir" "$tool" "$input" |
    env CLAUDE_PROJECT_DIR="$dir" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" "$@" bash "$HOOK" 2>"$TEST_ROOT/guard.err"
  echo "rc=$?"
}
bash_cmd() { claude "$1" Bash "{\"command\":$(json_escape "$2")}"; }
expect() {  # DESC RC OUTPUT
  local got="${3##*rc=}"
  if [ "$got" = "$2" ]; then pass "$1"; else fail "$1" "exit $got, expected $2; stderr: $(cat "$TEST_ROOT/guard.err")"; fi
}

section "file tools"
expect "edit in own worktree" 0 "$(claude "$A" Edit "$(obj file_path "$A/src/x.go" old_string a new_string b)")"
expect "edit in a sibling worktree" 2 "$(claude "$A" Edit "{\"file_path\":\"$B/src/x.go\"}")"
assert_contains "reason names the owner" "$(cat "$TEST_ROOT/guard.err")" "svc-b's repository"
assert_contains "reason offers the mailbox" "$(cat "$TEST_ROOT/guard.err")" "mail G-1 send --from svc-a --to coordinator"
expect "write to a main checkout" 2 "$(claude "$A" Write "$(obj file_path "$WS/svc-a/README.md" content x)")"
expect "write to another repo in the workspace" 2 "$(claude "$A" Write "$(obj file_path "$WS/unrelated/x" content x)")"
expect "write to the feature state" 0 "$(claude "$A" Write "$(obj file_path "$STATE/mail/coordinator/m.md" content x)")"
expect "write to a temp dir" 0 "$(claude "$A" Write "$(obj file_path "/tmp/fc-scratch.txt" content x)")"
expect "relative path inside" 0 "$(claude "$A" Write "$(obj file_path "src/y.go" content x)")"
expect "relative path escaping" 2 "$(claude "$A" Write "$(obj file_path "../../../svc-b/x" content x)")"
expect "coordinator edits the anchor" 0 "$(claude "$C" Edit "{\"file_path\":\"$C/docs/features/G-1/plan.md\"}")"
expect "coordinator edits a worker repo" 2 "$(claude "$C" Edit "{\"file_path\":\"$A/src/x.go\"}")"
expect "notebook edit outside" 2 "$(claude "$A" NotebookEdit "{\"notebook_path\":\"$B/n.ipynb\"}")"
expect "read tools are not checked" 0 "$(claude "$A" Read "{\"file_path\":\"$B/src/x.go\"}")"
big=$(python3 -c 'print("\"file_path\": \"/etc/passwd\" " * 2000)')
expect "content mentioning file_path does not confuse it" 0 "$(claude "$A" Write "$(obj file_path "$A/notes.md" content "$big")")"

section "locked contracts and protected paths"
expect "worker edits a locked contract" 2 "$(claude "$A" Edit "{\"file_path\":\"$A/api/openapi.yaml\"}")"
assert_contains "reason says ripple" "$(cat "$TEST_ROOT/guard.err")" "cross-service ripple"
expect "shell write to a locked contract" 2 "$(bash_cmd "$A" "echo x >> api/openapi.yaml")"
fw unlock G-1 --repo svc-a --path api/openapi.yaml --reason "approved" >/dev/null
expect "unlocked contract may change" 0 "$(claude "$A" Edit "{\"file_path\":\"$A/api/openapi.yaml\"}")"
fw lock G-1 >/dev/null 2>&1
out=$(claude "$A" Edit "{\"file_path\":\"$A/src/auth/login.go\"}")
expect "protected path in Claude Code exits 0" 0 "$out"
assert_contains "protected path asks your human partner" "$out" '"permissionDecision": "ask"'
out=$(claude "$A" Edit "{\"file_path\":\"$A/package.json\"}" COPILOT_CLI=1)
expect "protected path elsewhere is denied" 2 "$out"

section "shell commands"
expect "read-only commands" 0 "$(bash_cmd "$A" "git status && ls -la | grep x; cat $B/README.md")"
expect "redirect into a sibling" 2 "$(bash_cmd "$A" "echo hi > $B/x.txt")"
expect "stderr redirect is not a file write" 0 "$(bash_cmd "$A" "make test 2>&1 | tail -n 5")"
expect "append redirect inside" 0 "$(bash_cmd "$A" "echo hi >> notes.txt")"
expect "cd sibling then commit" 2 "$(bash_cmd "$A" "cd $B && git commit -am wip")"
expect "cd sibling then read" 0 "$(bash_cmd "$A" "cd $B && git log --oneline -5 && git diff")"
expect "git -C sibling commit" 2 "$(bash_cmd "$C" "git -C $A commit -m x")"
expect "git -C sibling status" 0 "$(bash_cmd "$C" "git -C $A status")"
expect "GIT_DIR pointing elsewhere" 2 "$(bash_cmd "$A" "GIT_DIR=$WS/svc-b/.git git reset --hard")"
expect "cp into a sibling" 2 "$(bash_cmd "$A" "cp -r src $B/src")"
expect "cp from a sibling" 0 "$(bash_cmd "$A" "cp $B/README.md ./theirs.md")"
expect "mv out of a sibling" 2 "$(bash_cmd "$A" "mv $B/x ./x")"
expect "rm in a sibling" 2 "$(bash_cmd "$A" "rm -rf $B/build")"
expect "sed -i in a sibling" 2 "$(bash_cmd "$A" "sed -i -e 's/a/b/' $B/x.txt")"
expect "sed -i inside" 0 "$(bash_cmd "$A" "sed -i 's/a/b/' src/x.txt")"
expect "tee into a sibling" 2 "$(bash_cmd "$A" "echo x | tee -a $B/log.txt")"
expect "bash -c nested write" 2 "$(bash_cmd "$A" "bash -lc 'touch $B/y'")"
expect "command substitution write" 2 "$(bash_cmd "$A" "echo \$(cp a $B/b)")"
expect "here-document body is data" 0 "$(bash_cmd "$A" "cat > notes.md <<'EOF'
rm -rf $B
git -C $B commit -m x
EOF
git add notes.md")"
expect "write after a here-document is still checked" 2 "$(bash_cmd "$A" "cat > notes.md <<EOF
text
EOF
touch $B/z")"
expect "quoted path with spaces" 2 "$(bash_cmd "$A" "touch \"$B/a file.txt\"")"

section "pushes, merges, approvals, unlock"
expect "force push" 2 "$(bash_cmd "$A" "git push --force origin HEAD")"
expect "short force flag" 2 "$(bash_cmd "$A" "git push -uf origin HEAD")"
expect "+refspec" 2 "$(bash_cmd "$A" "git push origin +HEAD:feat/G-1")"
expect "force-with-lease is allowed" 0 "$(bash_cmd "$A" "git push --force-with-lease origin HEAD")"
expect "push to main" 2 "$(bash_cmd "$A" "git push origin HEAD:main")"
expect "push to refs/heads/main" 2 "$(bash_cmd "$A" "git push origin feat/G-1:refs/heads/main")"
expect "push the feature branch" 0 "$(bash_cmd "$A" "git push -u origin feat/G-1")"
expect "gh pr merge" 2 "$(bash_cmd "$A" "gh pr merge 12 --squash")"
expect "gh pr review --approve" 2 "$(bash_cmd "$A" "gh pr review 12 --approve")"
expect "gh pr review comment" 0 "$(bash_cmd "$A" "gh pr review 12 --comment -b ok")"
expect "gh api merge" 2 "$(bash_cmd "$A" "gh api -X PUT repos/o/r/pulls/12/merge")"
expect "gh pr create" 0 "$(bash_cmd "$A" "gh pr create --draft --title x --body-file b.md")"
expect "az complete" 2 "$(bash_cmd "$A" "az repos pr update --id 7 --status completed")"
expect "az auto-complete" 2 "$(bash_cmd "$A" "az repos pr update --id 7 --auto-complete true")"
expect "az approve vote" 2 "$(bash_cmd "$A" "az repos pr set-vote --id 7 --vote approve")"
expect "az draft false" 0 "$(bash_cmd "$A" "az repos pr update --id 7 --draft false")"
expect "glab merge" 2 "$(bash_cmd "$A" "glab mr merge 3")"
expect "glab approve" 2 "$(bash_cmd "$A" "glab mr approve 3")"
expect "glab ready" 0 "$(bash_cmd "$A" "glab mr update 3 --ready")"
expect "glab back to draft" 0 "$(bash_cmd "$A" "glab mr update 3 --draft")"
expect "gh pr ready" 0 "$(bash_cmd "$A" "gh pr ready 12")"
expect "gh pr back to draft" 0 "$(bash_cmd "$A" "gh pr ready 12 --undo")"
assert_contains "merge denial points at the merge order" "$(bash_cmd "$A" "gh pr merge 12" >/dev/null; cat "$TEST_ROOT/guard.err")" "merge order"
expect "az back to draft" 0 "$(bash_cmd "$A" "az repos pr update --id 7 --draft true")"
expect "agent unlock" 2 "$(bash_cmd "$A" "bash $FW_SCRIPT unlock G-1 --repo svc-a --path p --reason r")"
expect "finish --force" 2 "$(bash_cmd "$C" "bash $FW_SCRIPT finish G-1 --force")"
expect "contract-check is fine" 0 "$(bash_cmd "$A" "bash $FW_SCRIPT contract-check G-1")"

section "Copilot payloads"
copilot() {  # DIR TOOL ARGS_JSON
  valid_json "$3" || { bad_input "$3"; return; }
  printf '{"timestamp":1,"cwd":"%s","toolName":"%s","toolArgs":%s}' "$1" "$2" "$(json_escape "$3")" |
    env FC_SESSION_WORKTREE="$1" COPILOT_CLI=1 bash "$HOOK" 2>"$TEST_ROOT/guard.err"
  echo "rc=$?"
}
expect "copilot edit outside" 2 "$(copilot "$A" edit "$(obj path "$B/x" old_str a new_str b)")"
expect "copilot create inside" 0 "$(copilot "$A" create "$(obj path "$A/new.txt" file_text x)")"
expect "copilot bash merge" 2 "$(copilot "$A" bash '{"command":"gh pr merge 3"}')"
expect "copilot bash ok" 0 "$(copilot "$A" bash '{"command":"npm test"}')"
expect "str_replace_editor view" 0 "$(claude "$A" str_replace_editor "$(obj command view path "$B/x")")"
expect "apply_patch outside" 2 "$(claude "$A" apply_patch "{\"input\":$(json_escape "*** Begin Patch
*** Update File: $B/m.go
@@
*** End Patch")}")"
# Array payloads go in variables (obj only builds strings).
in1="{\"command\":[\"bash\",\"-lc\",\"touch $B/q\"]}"
in2="{\"command\":[\"touch\",\"$B/q4\"]}"
in3="{\"command\":\"touch $B/q6\"}"
expect "codex-style command array" 2 "$(claude "$A" shell "$in1" FC_GUARD_DEBUG=1)"
expect "array command, plain touch" 2 "$(claude "$A" shell "$in2" FC_GUARD_DEBUG=1)"
expect "array command through the Bash tool name" 2 "$(claude "$A" Bash "$in2" FC_GUARD_DEBUG=1)"
expect "string command through the shell tool name" 2 "$(claude "$A" shell "$in3" FC_GUARD_DEBUG=1)"

section "identity and robustness"
expect "non-feature session passes" 0 "$(claude "$TEST_ROOT" Edit "{\"file_path\":\"$B/x\"}")"
out=$(printf 'not json' | env CLAUDE_PROJECT_DIR="$A" bash "$HOOK" 2>/dev/null; echo "rc=$?")
expect "garbage payload fails open" 0 "$out"
out=$(printf '{"cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s/x"}}' "$B" "$B" |
  env CLAUDE_PROJECT_DIR="$A" bash "$HOOK" 2>/dev/null; echo "rc=$?")
expect "identity comes from the project dir, not the shell's cwd" 2 "$out"
expect "FC_GUARD=off disables" 0 "$(claude "$A" Edit "{\"file_path\":\"$B/x\"}" FC_GUARD=off)"
start=$(date +%s)
long=$(python3 -c "print('cat > notes.md <<EOF\\n' + 'line \$x \"q\" (p) | & ; > <\\n' * 4000 + 'EOF\\ngit status')")
expect "large here-document" 0 "$(bash_cmd "$A" "$long")"
took=$(($(date +%s) - start))
if [ "$took" -le 3 ]; then pass "large command analysed in ${took}s"; else fail "large command analysed in ${took}s (limit 3s)"; fi


section "regressions from review"
expect "relative redirect after cd into a sibling" 2 "$(bash_cmd "$A" "cd $B && echo hi > notes.txt")"
expect "relative rm after cd into a sibling" 2 "$(bash_cmd "$A" "cd $B && rm -rf build")"
expect "relative sed -i after cd into a sibling" 2 "$(bash_cmd "$A" "cd $B && sed -i 's/a/b/' src/x.go")"
expect "relative write after cd inside" 0 "$(bash_cmd "$A" "mkdir -p src && cd src && echo hi > notes.txt")"
expect "apostrophe in a comment" 2 "$(bash_cmd "$A" "# Let's update svc-b too
cp client.go $B/client.go")"
expect "apostrophe in a coordinator comment" 2 "$(bash_cmd "$C" "# Coordinator's sync
git -C $A push --force origin HEAD")"
expect "trailing comment is ignored" 0 "$(bash_cmd "$A" "echo hi # don't worry")"
expect "deny wins over a protected-path ask" 2 "$(bash_cmd "$A" "sed -i 's/v1/v2/' src/auth/token.go $B/src/auth/token.go")"
expect "deny wins in either order" 2 "$(bash_cmd "$A" "sed -i 's/v1/v2/' $B/src/auth/token.go src/auth/token.go")"
out=$(bash_cmd "$A" "sed -i 's/v1/v2/' src/auth/token.go")
assert_contains "protected path alone still asks" "$out" '"permissionDecision": "ask"'
expect "cd inside a subshell does not leak" 0 "$(bash_cmd "$A" "(cd $B && git log -1) && git commit -am wip")"
expect "pushd and popd" 0 "$(bash_cmd "$A" "pushd $B && git log && popd && git commit -am wip")"
expect "cd -" 0 "$(bash_cmd "$A" "cd $B && git diff; cd - && git commit -am wip")"
expect "pushd then commit in the sibling" 2 "$(bash_cmd "$A" "pushd $B && git commit -am wip")"
expect "command substitution inside double quotes" 2 "$(bash_cmd "$A" "echo \"\$(git -C $B commit -am wip)\"")"
expect "backticks inside double quotes" 2 "$(bash_cmd "$A" "echo \"\`touch $B/t\`\"")"
expect "push deleting a remote branch" 2 "$(bash_cmd "$A" "git push origin :feat/G-1")"
expect "timeout wrapper" 2 "$(bash_cmd "$A" "timeout 60 git push --force origin HEAD")"
expect "timeout with options" 2 "$(bash_cmd "$A" "timeout -k 5 60 git push --force origin HEAD")"
expect "nice wrapper" 2 "$(bash_cmd "$A" "nice -n 10 git push --force origin HEAD")"
expect "sudo -u wrapper" 2 "$(bash_cmd "$A" "sudo -u bob git push -f origin HEAD")"
expect "Bitbucket merge over REST" 2 "$(bash_cmd "$A" "curl -X POST -u \"\$U:\$T\" https://api.bitbucket.org/2.0/repositories/w/r/pullrequests/12/merge")"
expect "Bitbucket approve over REST" 2 "$(bash_cmd "$A" "curl -s -X POST https://api.bitbucket.org/2.0/repositories/w/r/pullrequests/12/approve")"
expect "GitHub merged-check over REST is a read" 0 "$(bash_cmd "$A" "curl -sf -m 30 https://api.github.com/repos/o/r/pulls/12/merge")"
expect "GitHub merge over REST" 2 "$(bash_cmd "$A" "curl -X PUT https://api.github.com/repos/o/r/pulls/12/merge")"
expect "gh api approve review" 2 "$(bash_cmd "$A" "gh api repos/o/r/pulls/12/reviews -f event=APPROVE")"
expect "gh api merged-check" 0 "$(bash_cmd "$A" "gh api repos/o/r/pulls/12/merge")"
expect "glab api merge" 2 "$(bash_cmd "$A" "glab api --method PUT projects/:id/merge_requests/3/merge")"
expect "az rest complete" 2 "$(bash_cmd "$A" "az rest --method patch --url https://dev.azure.com/o/p/_apis/git/repositories/r/pullRequests/5 --body '{\"status\": \"completed\"}'")"
expect "tea merge" 2 "$(bash_cmd "$A" "tea pr merge 4")"
expect "tea approve" 2 "$(bash_cmd "$A" "tea pulls approve 4")"
expect "tea create" 0 "$(bash_cmd "$A" "tea pulls create --head feat/G-1 --base main --title x")"
expect "Gerrit submit over ssh" 2 "$(bash_cmd "$A" "ssh -p 29418 review.example.com gerrit review --submit 123,1")"
expect "Gerrit +2 over ssh" 2 "$(bash_cmd "$A" "ssh -p 29418 review.example.com gerrit review --code-review +2 123,1")"
expect "Gerrit change upload" 0 "$(bash_cmd "$A" "git push origin HEAD:refs/for/main")"
expect "Gerrit ready over REST" 0 "$(bash_cmd "$A" "curl -X POST https://review.example.com/a/changes/123/ready")"
expect "Gerrit back to wip over REST" 0 "$(bash_cmd "$A" "curl -X POST https://review.example.com/a/changes/123/wip")"
expect "Gerrit ready on push" 0 "$(bash_cmd "$A" "git push origin HEAD:refs/for/main%ready")"
expect "Bitbucket ready over REST" 0 "$(bash_cmd "$A" "curl -X PUT https://api.bitbucket.org/2.0/repositories/w/r/pullrequests/12 -d @ready.json")"
expect "Gitea title edit over REST" 0 "$(bash_cmd "$A" "curl -X PATCH https://gitea.example.com/api/v1/repos/o/r/pulls/4 -d @title.json")"
expect "Gerrit submit on push" 2 "$(bash_cmd "$A" "git push origin HEAD:refs/for/main%submit")"
expect "apply_patch Add File outside" 2 "$(claude "$A" apply_patch "{\"input\":$(json_escape "*** Begin Patch
*** Add File: $B/new.go
+package x
*** End Patch")}")"

# Windows-style identity: a stand-in cygpath maps C:\fc\... onto the workspace
cat >"$TEST_ROOT/bin/cygpath" <<EOF
#!/usr/bin/env bash
p="\$2"; p="\${p#C:\\\\fc\\\\}"; p="\${p//\\\\//}"
printf '%s\n' "$WS/\$p"
EOF
chmod +x "$TEST_ROOT/bin/cygpath"
WIN_A='C:\fc\svc-a\.worktrees\G-1'
out=$(printf '{"cwd":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' 'C:\\fc\\svc-a\\.worktrees\\G-1' 'C:\\fc\\svc-b\\.worktrees\\G-1\\x.go' |
  env CLAUDE_PROJECT_DIR="$WIN_A" bash "$HOOK" 2>/dev/null; echo "rc=$?")
expect "Windows project dir still identifies the session" 2 "$out"
rm -f "$TEST_ROOT/bin/cygpath"

finish_tests
