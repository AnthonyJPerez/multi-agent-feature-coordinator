#!/usr/bin/env bash
# End-to-end tests of the feature-workspace CLI against throwaway repos.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "feature-workspace"

WS=$(make_workspace life specs api-svc web)
cd "$WS" || exit 1

# Team config in the anchor, repo-owned gate in api-svc.
cat >specs/.feature-coordinator.conf <<'EOF'
# team stack
tracker = jira
tracker.url = https://acme.atlassian.net
chat = slack
chat.webhook_env = FC_SLACK_WEBHOOK
branch_prefix = feature/
gate.web = true
model.web = opus
EOF
commit_and_push specs "team config" .feature-coordinator.conf
printf 'gate = test -f ok.txt\n' >api-svc/.feature-coordinator.conf
commit_and_push api-svc "repo gate" .feature-coordinator.conf
printf '.env.local\n' >api-svc/.gitignore
printf '.env.local\n' >api-svc/.worktreeinclude
commit_and_push api-svc "worktreeinclude" .gitignore .worktreeinclude
printf 'SECRET=1\n' >api-svc/.env.local

STATE="$WS/.feature/FEAT-1"
ANCHOR_WT="$WS/specs/.worktrees/FEAT-1"
API_WT="$WS/api-svc/.worktrees/FEAT-1"
WEB_WT="$WS/web/.worktrees/FEAT-1"

section "config before a feature"
out=$(fw config --anchor specs 2>&1)
assert_contains "reads tracker from the anchor's team file" "$out" "jira"
assert_contains "names the source file" "$out" "specs/.feature-coordinator.conf"
out=$(FC_TRACKER=linear fw config --anchor specs 2>&1)
assert_contains "environment overrides the team file" "$out" "environment FC_TRACKER"
out=$(FC_TRACKER=asana fw config --anchor specs 2>&1); rc=$?
assert_rc "rejects an unknown tracker" "$rc" 1 "$out"
assert_contains "explains the invalid value" "$out" "invalid tracker 'asana'"
out=$(FC_BRANCH_PREFIX=../evil fw config --anchor specs 2>&1); rc=$?
assert_rc "rejects a branch prefix with .." "$rc" 1 "$out"

section "start"
out=$(fw start FEAT-1 --anchor specs --repo api-svc --repo web 2>&1); rc=$?
assert_rc "start succeeds" "$rc" 0 "$out"
assert_file "anchor worktree" "$ANCHOR_WT/README.md"
assert_file "api worktree" "$API_WT/README.md"
assert_file "web worktree" "$WEB_WT/README.md"
assert_eq "anchor branch uses the prefix" "$(git -C "$ANCHOR_WT" branch --show-current)" "feature/FEAT-1-spec"
assert_eq "worker branch uses the prefix" "$(git -C "$API_WT" branch --show-current)" "feature/FEAT-1"
assert_file ".worktreeinclude copied" "$API_WT/.env.local"
assert_contains ".worktrees/ excluded" "$(cat "$WS/api-svc/.git/info/exclude")" ".worktrees/"
assert_file "per-worktree record" "$WS/api-svc/.git/feature-coordinator/FEAT-1.env"
assert_contains "config snapshot" "$(cat "$STATE/config.env")" "FC_CFG_TRACKER=jira"
gate_api=$(awk -F '\t' '$1 == "api-svc" { print $7 }' "$STATE/repos.tsv")
gate_web=$(awk -F '\t' '$1 == "web" { print $7 }' "$STATE/repos.tsv")
assert_eq "repo-owned gate" "$gate_api" "test -f ok.txt"
assert_eq "team gate.<repo>" "$gate_web" "true"
assert_eq "coordinator row first" "$(head -n 1 "$STATE/repos.tsv" | cut -f1)" "coordinator"
assert_eq "a remote that is a folder counts as local" "$(awk -F '\t' '$1 == "web" { print $8 }' "$STATE/repos.tsv")" "local"
assert_contains "prints provider references" "$out" "providers/jira.md"
assert_contains "prints the slack reference" "$out" "providers/slack.md"

out=$(fw start FEAT-1 --anchor specs --repo api-svc --repo web --gate web=make 2>&1); rc=$?
assert_rc "start is re-runnable" "$rc" 0 "$out"
assert_eq "--gate overrides on re-run" "$(awk -F '\t' '$1 == "web" { print $7 }' "$STATE/repos.tsv")" "make"
assert_eq "still three participants" "$(wc -l <"$STATE/repos.tsv" | tr -d ' ')" "3"
fw start FEAT-1 --anchor specs --repo api-svc --repo web --gate web=true >/dev/null 2>&1

out=$(fw start ../evil --anchor specs 2>&1); rc=$?
assert_rc "rejects an unsafe feature ID" "$rc" 1 "$out"
out=$(fw start FEAT-1 --anchor api-svc 2>&1); rc=$?
assert_rc "refuses to switch the anchor" "$rc" 1 "$out"

section "where and config inside a worktree"
out=$(cd "$API_WT/" && fw where 2>&1)
assert_contains "where: role" "$out" "worker for api-svc"
assert_contains "where: brief path" "$out" "briefs/worker-api-svc.md"
assert_contains "where: docs path" "$out" "$ANCHOR_WT/docs/features/FEAT-1"
out=$(cd "$ANCHOR_WT" && fw where 2>&1)
assert_contains "where: coordinator" "$out" "coordinator (anchor repo specs)"
out=$(cd "$WS" && fw where 2>&1); rc=$?
assert_rc "where outside a worktree fails" "$rc" 1 "$out"
out=$(fw config FEAT-1 2>&1)
assert_contains "config <ID> shows the snapshot" "$out" "branch_prefix     feature/"

section "launch"
fake_cli claude "Usage: claude [options]
  --add-dir <directories...>
  --effort <level>
  --model <model>"
fake_cli copilot "Usage: copilot [options]
  --add-dir <directory>
  -i, --interactive <prompt>"
fake_cli codex "Usage: codex [options]
  --sandbox <mode>
  --add-dir <dir>"
cmd=$(fw launch FEAT-1 coordinator 2>&1)
assert_contains "coordinator: model" "$cmd" "--model opus"
assert_contains "coordinator: effort from the CLI help" "$cmd" "--effort high"
run=$(eval "$cmd")
assert_contains "coordinator runs in the anchor worktree" "$run" "PWD=$ANCHOR_WT"
assert_contains "coordinator: session variable" "$run" "FC_SESSION_WORKTREE=$ANCHOR_WT"
assert_contains "coordinator: CLAUDE.md loading for added dirs" "$run" "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1"
assert_contains "coordinator: reads api worktree" "$run" "ARG=$API_WT"
assert_contains "coordinator: reads web worktree" "$run" "ARG=$WEB_WT"
assert_contains "coordinator: state dir" "$run" "ARG=$STATE"
assert_contains "coordinator: prompt names the skill" "$run" "coordinating-multi-repo-features"
run=$(eval "$(fw launch FEAT-1 api-svc)")
assert_contains "worker: default worker model" "$run" "ARG=sonnet"
assert_contains "worker: reads the anchor worktree" "$run" "ARG=$ANCHOR_WT"
assert_not_contains "worker: no sibling worktree" "$run" "ARG=$WEB_WT"
run=$(eval "$(fw launch FEAT-1 web)")
assert_contains "worker: model.<repo> override" "$run" "ARG=opus"
run=$(eval "$(fw launch FEAT-1 api-svc --cli copilot)")
assert_contains "copilot: interactive prompt" "$run" "ARG=-i"
assert_contains "copilot: add-dir" "$run" "ARG=$ANCHOR_WT"
run=$(eval "$(fw launch FEAT-1 api-svc --cli codex)")
assert_contains "codex: sandbox" "$run" "ARG=workspace-write"
assert_contains "codex: state dir writable" "$run" "ARG=$STATE"
assert_contains "codex: git dir writable" "$run" "ARG=$WS/api-svc/.git"
assert_not_contains "codex: anchor worktree not writable" "$run" "ARG=$ANCHOR_WT"
out=$(fw launch FEAT-1 nosuch 2>&1); rc=$?
assert_rc "launch rejects an unknown target" "$rc" 1 "$out"
out=$(fw launch FEAT-1 workers 2>&1)
assert_eq "launch workers prints two commands" "$(printf '%s\n' "$out" | grep -c '^cd ')" "2"

section "dispatch needs a lock"
out=$(fw dispatch FEAT-1 2>&1); rc=$?
assert_rc "dispatch refuses without a lock" "$rc" 1 "$out"
assert_contains "explains why" "$out" "no contract lock"

section "spec and plan merged, then lock"
mkdir -p "$ANCHOR_WT/docs/features/FEAT-1"
printf '# spec\n' >"$ANCHOR_WT/docs/features/FEAT-1/spec.md"
commit_and_push "$ANCHOR_WT" "spec" docs/features/FEAT-1/spec.md
merge_to_main "$WS/specs" feature/FEAT-1-spec
git -C "$ANCHOR_WT" fetch -q origin
git -C "$ANCHOR_WT" switch -q -c feature/FEAT-1-plan origin/main
C="$ANCHOR_WT/docs/features/FEAT-1/contracts"
mkdir -p "$C/api-svc/api" "$C/web/src" "$C/stranger"
printf 'openapi: 3.1.0\ninfo: {title: api, version: "2"}\n' >"$C/api-svc/api/openapi.yaml"
printf 'export type Invoice = { id: string }\n' >"$C/web/src/api-types.ts"
printf 'x\n' >"$C/stranger/file.txt"
printf '# plan\n' >"$ANCHOR_WT/docs/features/FEAT-1/plan.md"
commit_and_push "$ANCHOR_WT" "plan" docs/features/FEAT-1
out=$(fw lock FEAT-1 2>&1); rc=$?
assert_rc "lock before the plan merges finds no contracts" "$rc" 1 "$out"
merge_to_main "$WS/specs" feature/FEAT-1-plan
out=$(fw lock FEAT-1 2>&1); rc=$?
assert_rc "lock after merge" "$rc" 0 "$out"
assert_contains "locks two files" "$out" "Locked 2 contract file(s)"
assert_contains "warns about non-participants" "$out" "'stranger' is not a worker repo"
assert_eq "lock rows" "$(grep -vc '^#' "$STATE/contracts.lock")" "2"

section "dispatch and briefs"
out=$(fw dispatch FEAT-1 2>&1); rc=$?
assert_rc "dispatch succeeds" "$rc" 0 "$out"
BRIEF="$STATE/briefs/worker-api-svc.md"
assert_file "brief written" "$BRIEF"
brief=$(cat "$BRIEF")
assert_not_contains "no unreplaced placeholders" "$brief" "{{"
assert_contains "brief: contract" "$brief" "api/openapi.yaml"
assert_contains "brief: gate" "$brief" "test -f ok.txt"
assert_contains "brief: tracker" "$brief" "**jira**"
assert_contains "brief: provider reference" "$brief" "providers/jira.md"
assert_contains "brief: branch" "$brief" "feature/FEAT-1"
assert_contains "brief: docs folder" "$brief" "$ANCHOR_WT/docs/features/FEAT-1/plan.md"
assert_contains "dispatch prints launch commands" "$out" "working-a-repo-slice"

section "apply-contract and contract-check"
out=$(cd "$API_WT" && fw apply-contract FEAT-1 2>&1)
assert_contains "apply-contract writes the file" "$out" "wrote api/openapi.yaml"
assert_eq "content matches the lock" "$(cat "$API_WT/api/openapi.yaml")" "$(printf 'openapi: 3.1.0\ninfo: {title: api, version: "2"}')"
out=$(cd "$API_WT" && fw contract-check FEAT-1 2>&1); rc=$?
assert_rc "contract-check passes" "$rc" 0 "$out"
git -C "$API_WT" add api/openapi.yaml && git -C "$API_WT" commit -qm "FEAT-1: apply locked contracts"
printf 'tampered\n' >>"$API_WT/api/openapi.yaml"
out=$(cd "$API_WT" && fw contract-check FEAT-1 2>&1); rc=$?
assert_rc "contract-check catches drift" "$rc" 1 "$out"
assert_contains "names the drifted file" "$out" "changed   api/openapi.yaml"
assert_contains "status shows drift" "$(fw status FEAT-1 --no-remote 2>&1)" "DRIFT"
fw unlock FEAT-1 --repo api-svc --path api/openapi.yaml --reason "approved amendment" >/dev/null
out=$(cd "$API_WT" && fw contract-check FEAT-1 2>&1); rc=$?
assert_rc "unlock exempts the file" "$rc" 0 "$out"
fw lock FEAT-1 >/dev/null 2>&1
out=$(cd "$API_WT" && fw contract-check FEAT-1 2>&1); rc=$?
assert_rc "re-lock clears the exemption" "$rc" 1 "$out"
git -C "$API_WT" checkout -q -- api/openapi.yaml
out=$(fw contract-check FEAT-1 --repo web 2>&1); rc=$?
assert_rc "missing contract file is drift" "$rc" 1 "$out"
assert_contains "reports it missing" "$out" "missing   src/api-types.ts"

section "mail and decisions"
out=$(fw mail FEAT-1 send --from api-svc --to coordinator --subject "Ripple: invoice id" --body "id must be a string" 2>&1); rc=$?
assert_rc "mail send" "$rc" 0 "$out"
out=$(fw mail FEAT-1 inbox --for coordinator 2>&1)
assert_contains "inbox shows the message" "$out" "Subject: Ripple: invoice id"
assert_contains "inbox shows the body" "$out" "id must be a string"
out=$(fw mail FEAT-1 inbox --for coordinator 2>&1)
assert_contains "read messages move out of the inbox" "$out" "No new messages"
out=$(printf 'from stdin\n' | fw mail FEAT-1 send --from coordinator --to web --subject s 2>&1)
assert_contains "body from stdin" "$(cat "$STATE"/mail/web/*.md)" "from stdin"
out=$(fw mail FEAT-1 send --from x --to nobody --subject s --body b 2>&1); rc=$?
assert_rc "unknown recipient rejected" "$rc" 1 "$out"
out=$(fw log-decision FEAT-1 --who api-svc --tier 2 --decision "Use RFC 7807 errors" --why "Matches gateway" 2>&1); rc=$?
assert_rc "log-decision" "$rc" 0 "$out"
assert_contains "decision recorded" "$(cat "$STATE/decisions.md")" "Use RFC 7807 errors"
assert_contains "tier recorded" "$(cat "$STATE/decisions.md")" "api-svc - Tier 2"
out=$(fw log-decision FEAT-1 --tier 5 --decision d --why w 2>&1); rc=$?
assert_rc "invalid tier rejected" "$rc" 1 "$out"

section "status and list"
out=$(fw status FEAT-1 --no-remote 2>&1)
assert_contains "local repo without commits" "$out" "| web | worker | feature/FEAT-1 |"
assert_contains "local repo: no commits yet" "$(printf '%s\n' "$out" | grep '^| web ')" "no commits yet"
assert_contains "local repo: commits but no packet" "$(printf '%s\n' "$out" | grep '^| api-svc ')" "1 commit(s), no review packet"
printf 'Status: draft\n' >"$STATE/reviews/api-svc.md"
out=$(fw status FEAT-1 --no-remote 2>&1)
assert_contains "local repo: review packet" "$(printf '%s\n' "$out" | grep '^| api-svc ')" "review packet, 1 commit(s)"
assert_contains "status lists the coordinator" "$out" "| coordinator | anchor |"
assert_contains "status lists a worker" "$out" "| api-svc | worker | feature/FEAT-1 |"
assert_contains "status shows the tracker" "$out" "Tracker: jira"
assert_contains "list shows the feature" "$(fw list 2>&1)" "FEAT-1  anchor=specs"

section "finish"
out=$(fw finish FEAT-1 2>&1); rc=$?
assert_rc "finish refuses unmerged work" "$rc" 1 "$out"
assert_contains "names the unmerged branch" "$out" "api-svc: feature/FEAT-1 has commits that are not merged"
git -C "$API_WT" push -q -u origin feature/FEAT-1 2>/dev/null
merge_to_main "$WS/api-svc" feature/FEAT-1
assert_contains "local repo: merged" "$(fw status FEAT-1 --no-remote 2>&1 | grep '^| api-svc ')" "merged into main"
out=$(fw finish FEAT-1 2>&1); rc=$?
assert_rc "finish after merge" "$rc" 0 "$out"
assert_no_file "worktree removed" "$API_WT"
assert_no_file "anchor worktree removed" "$ANCHOR_WT"
assert_no_file "record removed" "$WS/api-svc/.git/feature-coordinator/FEAT-1.env"
assert_eq "branch deleted" "$(git -C "$WS/api-svc" branch --list feature/FEAT-1)" ""
assert_no_file "state moved" "$STATE"
assert_contains "state archived" "$(ls "$WS/.feature/_archive")" "FEAT-1-"


section "per-repo code hosts"
WS3=$(make_workspace hosts anchor svc web)
cd "$WS3" || exit 1
cat >anchor/.feature-coordinator.conf <<'EOF'
code_host = auto
code_host.web = gitlab      # self-managed GitLab on a custom domain
EOF
commit_and_push anchor conf .feature-coordinator.conf
printf 'code_host = gerrit\n' >svc/.feature-coordinator.conf
commit_and_push svc conf .feature-coordinator.conf
out=$(fw start H-1 --anchor anchor --repo svc --repo web 2>&1); rc=$?
assert_rc "start with mixed hosts" "$rc" 0 "$out"
host_of() { awk -F '\t' -v w="$1" '$1 == w { print $8 }' "$WS3/.feature/H-1/repos.tsv"; }
assert_eq "code_host.<repo> in the team file (inline comment ignored)" "$(host_of web)" "gitlab"
assert_eq "a repo's own code_host" "$(host_of svc)" "gerrit"
assert_eq "detection for the rest" "$(host_of coordinator)" "local"
assert_contains "references for every host" "$out" "providers/gerrit.md"
assert_contains "gitlab reference" "$out" "providers/gitlab.md"
assert_contains "local reference" "$out" "providers/local.md"
printf 'code_host.web = gitea\n' >"$WS3/.feature/config"
out=$(fw config H-1 --refresh 2>&1)
assert_eq "config --refresh re-detects hosts" "$(host_of web)" "gitea"
printf 'code_host.web = svn\n' >"$WS3/.feature/config"
out=$(fw config H-1 --refresh 2>&1); rc=$?
assert_rc "an unknown host is rejected" "$rc" 1 "$out"
rm -f "$WS3/.feature/config"
SVC_WT="$WS3/svc/.worktrees/H-1"
printf 'x\n' >"$SVC_WT/change.txt"
git -C "$SVC_WT" add change.txt && git -C "$SVC_WT" commit -qm "change"
sha=$(git -C "$SVC_WT" rev-parse HEAD)
git -C "$WS3/svc" cherry-pick "$sha" >/dev/null 2>&1
git -C "$WS3/svc" push -q origin main 2>/dev/null
out=$(fw finish H-1 2>&1); rc=$?
assert_rc "a cherry-picked (Gerrit-style) submit counts as merged" "$rc" 0 "$out"
cd "$WS" || exit 1

section "regressions from review"
WS2=$(make_workspace regress anchor svc)
cd "$WS2" || exit 1
git -C svc checkout -q -b feat/X-1
out=$(fw start X-1 --anchor anchor --repo svc 2>&1); rc=$?
assert_rc "start stops when a worktree cannot be created" "$rc" 1 "$out"
assert_contains "and says why" "$out" "could not create"
git -C svc checkout -q main
out=$(cd "$WS2/anchor" && fw start D-1 --anchor . --repo ../svc 2>&1); rc=$?
assert_rc "start with --anchor ." "$rc" 0 "$out"
assert_file "state lands in the workspace" "$WS2/.feature/D-1/feature.env"
assert_no_file "not inside the anchor repo" "$WS2/anchor/.feature"
out=$(cd "$WS2" && fw status D-1 --no-remote 2>&1); rc=$?
assert_rc "status finds it from the workspace" "$rc" 0 "$out"
git -C "$WS2/svc" worktree lock "$WS2/svc/.worktrees/D-1"
out=$(cd "$WS2" && fw finish D-1 2>&1); rc=$?
assert_rc "finish reports a worktree it cannot remove" "$rc" 1 "$out"
assert_contains "names it" "$out" "Could not remove the worktree of: svc"
assert_file "keeps that repo's record" "$WS2/svc/.git/feature-coordinator/D-1.env"
assert_file "keeps the feature state" "$WS2/.feature/D-1/feature.env"
assert_no_file "still cleans the others" "$WS2/anchor/.worktrees/D-1"
git -C "$WS2/svc" worktree unlock "$WS2/svc/.worktrees/D-1"
out=$(cd "$WS2" && fw finish D-1 2>&1); rc=$?
assert_rc "finish completes on the second run" "$rc" 0 "$out"
assert_no_file "state archived after the second run" "$WS2/.feature/D-1"
cd "$WS" || exit 1

section "code host detection"
mk_remote_repo() {  # NAME URL
  git init -q "$TEST_ROOT/hosts/$1"
  git -C "$TEST_ROOT/hosts/$1" remote add origin "$2"
}
mkdir -p "$TEST_ROOT/hosts"
mk_remote_repo gh git@github.com:acme/payments.git
mk_remote_repo ado https://contoso@dev.azure.com/contoso/Payments%20Team/_git/billing
mk_remote_repo adossh git@ssh.dev.azure.com:v3/contoso/Payments/billing
mk_remote_repo vsts https://contoso.visualstudio.com/DefaultCollection/Payments/_git/billing
mk_remote_repo gl https://gitlab.example.com/platform/core/api.git
mk_remote_repo bb git@bitbucket.org:acme/web.git
mk_remote_repo other https://git.example.com/x/y.git
detect() { bash -c '. "$1"; fc_detect_host "$2"' _ "$FC_LIB" "$TEST_ROOT/hosts/$1"; }
assert_eq "github" "$(detect gh)" "github"
assert_eq "azure https" "$(detect ado)" "azure-repos"
assert_eq "azure ssh" "$(detect adossh)" "azure-repos"
assert_eq "visualstudio.com" "$(detect vsts)" "azure-repos"
assert_eq "gitlab" "$(detect gl)" "gitlab"
assert_eq "bitbucket" "$(detect bb)" "bitbucket"
assert_eq "a git server with no known PR system" "$(detect other)" "other"
git init -q "$TEST_ROOT/hosts/noremote"
assert_eq "no remote at all" "$(detect noremote)" "local"
mk_remote_repo pathremote /srv/git/payments.git
mk_remote_repo fileurl file:///srv/git/payments.git
mk_remote_repo tfs https://tfs.contoso.internal/tfs/DefaultCollection/Payments/_git/ledger
mk_remote_repo gerrit ssh://review.contoso.internal:29418/platform/pricing
mk_remote_repo codeberg https://codeberg.org/acme/tools.git
assert_eq "folder remote" "$(detect pathremote)" "local"
assert_eq "file:// remote" "$(detect fileurl)" "local"
assert_eq "Azure DevOps Server" "$(detect tfs)" "azure-repos"
assert_eq "Gerrit on port 29418" "$(detect gerrit)" "gerrit"
assert_eq "Codeberg" "$(detect codeberg)" "gitea"
azref() { bash -c '. "$1"; fc_azure_ref "$2"' _ "$FC_LIB" "$TEST_ROOT/hosts/$1"; }
assert_eq "azure ref (https)" "$(azref ado)" "$(printf 'https://dev.azure.com/contoso\tPayments%%20Team\tbilling')"
assert_eq "azure ref (ssh)" "$(azref adossh)" "$(printf 'https://dev.azure.com/contoso\tPayments\tbilling')"
assert_eq "azure ref (visualstudio.com)" "$(azref vsts)" "$(printf 'https://dev.azure.com/contoso\tPayments\tbilling')"
assert_eq "azure ref (Azure DevOps Server)" "$(azref tfs)" "$(printf 'https://tfs.contoso.internal/tfs/DefaultCollection\tPayments\tledger')"
assert_eq "gitlab path" "$(bash -c '. "$1"; fc_gitlab_path "$2"' _ "$FC_LIB" "$TEST_ROOT/hosts/gl")" "platform/core/api"
assert_eq "github slug" "$(bash -c '. "$1"; fc_github_slug "$2"' _ "$FC_LIB" "$TEST_ROOT/hosts/gh")" "acme/payments"

section "path helpers"
lib() { bash -c '. "$1"; shift; "$@"' _ "$FC_LIB" "$@"; }
assert_eq "normpath removes .." "$(lib fc_normpath /a/b/../c/./d)" "/a/c/d"
assert_eq "normpath relative" "$(lib fc_normpath x/y /base)" "/base/x/y"
assert_eq "windows drive path" "$(lib fc_to_unix 'C:\Users\ana\ws')" "/c/Users/ana/ws"
assert_eq "protected glob" "$(lib fc_path_protected src/auth/login.go '**/auth/**' && echo yes)" "yes"
assert_eq "unprotected path" "$(lib fc_path_protected docs/readme.md '**/auth/**' || echo no)" "no"

finish_tests
