#!/usr/bin/env bash
# bump-version.sh - keep every manifest's version in step.
#
#   scripts/bump-version.sh <new-version>   set the version everywhere
#   scripts/bump-version.sh --check         print versions, fail on drift
#   scripts/bump-version.sh --audit         --check, then grep for stray copies
#
# Files and fields come from .version-bump.json. Development-time only; needs jq.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/.version-bump.json"
command -v jq >/dev/null 2>&1 || { echo "bump-version: jq is required" >&2; exit 1; }
[ -f "$CONFIG" ] || { echo "bump-version: missing $CONFIG" >&2; exit 1; }

jq_path() { # plugins.0.version -> .plugins[0].version
  printf '.%s' "$1" | sed -E 's/\.([0-9]+)/[\1]/g'
}

entries() { jq -r '.files[] | "\(.path)\t\(.field)"' "$CONFIG"; }

check() {
  local path field v first="" drift=0
  while IFS=$'\t' read -r path field; do
    v=$(jq -r "$(jq_path "$field")" "$ROOT/$path")
    printf '%-36s %-22s %s\n' "$path" "$field" "$v"
    if [ -z "$first" ]; then first="$v"; elif [ "$v" != "$first" ]; then drift=1; fi
  done < <(entries)
  if [ "$drift" = 1 ]; then echo "bump-version: versions differ" >&2; return 1; fi
  CURRENT="$first"
}

audit() {
  local excludes=() e
  while IFS= read -r e; do excludes+=("--exclude-dir=$e" "--exclude=$e"); done < <(jq -r '.audit.exclude[]' "$CONFIG")
  echo "Other mentions of $CURRENT:"
  grep -rnF "${excludes[@]}" -- "$CURRENT" "$ROOT" | grep -vF -f <(entries | cut -f1 | sed "s|^|$ROOT/|") || echo "  none"
}

case "${1:-}" in
  --check) check ;;
  --audit) check; audit ;;
  '' | -h | --help) sed -n '2,8p' "$0" ;;
  *)
    new="$1"
    [[ $new =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] || { echo "bump-version: '$new' is not a version" >&2; exit 1; }
    while IFS=$'\t' read -r path field; do
      tmp="$ROOT/$path.tmp"
      jq --indent 2 "$(jq_path "$field") = \"$new\"" "$ROOT/$path" >"$tmp"
      mv "$tmp" "$ROOT/$path"
    done < <(entries)
    check
    ;;
esac
