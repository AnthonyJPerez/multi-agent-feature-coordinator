#!/usr/bin/env bash
# The bash constructs the runtime scripts rely on, checked on whatever bash
# runs the tests - CI runs this with macOS's bash 3.2 as well as bash 5.
. "$(cd "$(dirname "$0")/.." && pwd)/lib.sh"

echo "bash constructs ($BASH_VERSION)"
SQ="'"
DQ='"'
TAB=$(printf '\t')
EOT=$(printf '\004')

s="ab${SQ}cd"
assert_eq "remove from the first quote (variable)" "${s%%"$SQ"*}" "ab"
assert_eq "remove from the first quote (literal)" "${s%%"'"*}" "ab"
if [[ "$s" == *"$SQ"* ]]; then pass "[[ == ]] with a quote variable"; else fail "[[ == ]] with a quote variable"; fi
if [[ "$s" == *"'"* ]]; then pass "[[ == ]] with a literal quote"; else fail "[[ == ]] with a literal quote"; fi

t="${TAB}${TAB}x"
assert_eq "strip leading tabs (variable)" "${t#"${t%%[!$TAB]*}"}" "x"
assert_eq "strip leading tabs (ANSI-C)" "${t#"${t%%[!$'\t']*}"}" "x"

chunk_of() { local part="$1"; printf '%s' "${part%%[\'\"\\\$\`$' \t;|&()<>']*}"; }
assert_eq "chunk stops at space" "$(chunk_of 'abc def')" "abc"
assert_eq "chunk keeps the letter t" "$(chunk_of 'git x')" "git"
assert_eq "chunk stops at a quote" "$(chunk_of "ab${SQ}t")" "ab"
assert_eq "chunk stops at a double quote" "$(chunk_of "ab${DQ}t")" "ab"
assert_eq "chunk stops at ;" "$(chunk_of 'ab;c')" "ab"
assert_eq "chunk stops at a tab" "$(chunk_of "ab${TAB}c")" "ab"

dq_chunk() { local part="$1"; printf '%s' "${part%%[\"\\\$\`]*}"; }
assert_eq "double-quote chunk stops at \$" "$(dq_chunk 'ab$(x)')" "ab"
assert_eq "double-quote chunk stops at a quote" "$(dq_chunk "ab${DQ}c")" "ab"

X_array=1
arr=X_array
assert_eq "indirect with default" "${!arr:-}" "1"
unset Y_missing
arr=Y_missing
assert_eq "indirect with default, unset" "${!arr:-none}" "none"
var=X_array
assert_eq "indirect +x" "${!var+x}" "x"

rest="a${EOT}b c${EOT}"
assert_eq "split at a control char" "${rest%%"$EOT"*}" "a"
assert_eq "drop through a control char" "${rest#*"$EOT"}" "b c${EOT}"

SQ_ESC="'\\''"
e="it${SQ}s"
assert_eq "quote escaping by substitution" "${SQ}${e//$SQ/$SQ_ESC}${SQ}" "'it'\\''s'"

w="abcdef"
i=2
assert_eq "substring with arithmetic" "${w:i+1:1}" "d"
printf -v out '%s-%s' x y
assert_eq "printf -v" "$out" "x-y"
rec=""
while IFS= read -r -d "$(printf '\003')" r; do rec="$rec[$r]"; done < <(printf 'a\003b c\003')
assert_eq "read -d with a control char" "$rec" "[a][b c]"
words=(one two three)
set -- ${words[@]+"${words[@]:1}"}
assert_eq "array slice" "$*" "two three"

finish_tests
