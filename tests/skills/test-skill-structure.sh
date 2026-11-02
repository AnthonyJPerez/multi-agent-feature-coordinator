#!/usr/bin/env bash
# Skill conventions: frontmatter, trigger-only descriptions, size limit,
# referenced files exist, voice.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "skill structure"
cd "$REPO_ROOT/skills" || exit 1

count=0
for dir in */; do
  name="${dir%/}"
  f="$name/SKILL.md"
  count=$((count + 1))
  if [ ! -f "$f" ]; then fail "$name has SKILL.md"; continue; fi
  first=$(head -n 1 "$f")
  assert_eq "$name: frontmatter opens" "$first" "---"
  fm=$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$f")
  fm_name=$(printf '%s\n' "$fm" | sed -n 's/^name: //p')
  desc=$(printf '%s\n' "$fm" | sed -n 's/^description: //p')
  keys=$(printf '%s\n' "$fm" | sed -n 's/^\([a-z_-]*\):.*/\1/p' | tr '\n' ' ')
  assert_eq "$name: name matches folder" "$fm_name" "$name"
  assert_eq "$name: only name and description" "$keys" "name description "
  case "$desc" in "Use when"* | "Use only when"*) pass "$name: description starts with a trigger" ;;
    *) fail "$name: description starts with a trigger" "$desc" ;; esac
  if [ "${#desc}" -le 500 ]; then pass "$name: description is short"; else fail "$name: description is short (${#desc})"; fi
  size=$(wc -c <"$f" | tr -d ' ')
  if [ "$size" -lt 20000 ]; then pass "$name: SKILL.md under 20000 bytes ($size)"; else fail "$name: SKILL.md under 20000 bytes ($size)"; fi
  if grep -qiE '\bthe user\b' "$f"; then fail "$name: says 'your human partner', not 'the user'"; else pass "$name: voice"; fi
  # backticked relative files that the skill tells the agent to open
  for ref in $(grep -oE '`(references|templates)/[A-Za-z0-9._/-]+\.(md|conf)`|`[a-z-]+-(template|prompt|templates)\.md`|`(decision-block|reply-templates)\.md`' "$f" | tr -d '`' | sort -u); do
    assert_file "$name: referenced $ref exists" "$name/$ref"
  done
done
assert_eq "twelve skills" "$count" "12"

section "bootstrap"
B=using-feature-coordinator/SKILL.md
for h in claude-code copilot-cli codex cursor gemini; do
  assert_file "tool mapping for $h" "using-feature-coordinator/references/$h-tools.md"
done
for s in */; do
  s="${s%/}"
  [ "$s" = using-feature-coordinator ] && continue
  assert_contains "bootstrap routes to $s" "$(cat "$B")" "$s"
done
assert_contains "bootstrap scopes itself to multi-repo work" "$(cat "$B")" "do not
apply to ordinary single-repo work"

section "provider references"
P=using-feature-coordinator/references/providers
for f in github azure-devops gitlab bitbucket jira linear teams slack discord; do
  assert_file "provider reference $f" "$P/$f.md"
done
while IFS= read -r ref; do
  assert_file "fc_provider_ref target $ref" "$P/$ref"
done < <(sed -n 's/.*) echo \([a-z-]*\.md\) ;;.*/\1/p' "$REPO_ROOT/skills/coordinating-multi-repo-features/scripts/fc-lib")
for f in "$P"/*.md; do
  if grep -qiE 'merge --auto|set-vote --vote approve|mr approve' "$f" && ! grep -q 'Never' "$f"; then
    fail "$(basename "$f") mentions merge/approve without forbidding it"
  else
    pass "$(basename "$f") does not instruct merging or approving"
  fi
done

section "templates the scripts use"
assert_file "worker brief template" dispatching-repo-workers/worker-brief-template.md
for ph in FEATURE_ID REPO WORKTREE BRANCH DEFAULT_BRANCH FEATURE_DOCS LOCK_COMMIT CONTRACTS GATE SCRIPT STATE CODE_HOST TRACKER CHAT PROVIDER_REFS; do
  assert_contains "brief template uses {{$ph}}" "$(cat dispatching-repo-workers/worker-brief-template.md)" "{{$ph}}"
done

finish_tests
