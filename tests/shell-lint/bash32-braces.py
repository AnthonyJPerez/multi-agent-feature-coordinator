#!/usr/bin/env python3
"""Find "$(...)" words that bash 3.2 would brace-expand.

bash 3.2's brace_gobbler tracks quotes without knowing that a command
substitution inside double quotes has its own quoting, so in
"$(f "{\"a\":1,\"b\":2}")" the inner quotes toggle its state and the
braces look unquoted: the word is split into one command substitution per
alternative. This emulates that scan for every "$( word in the files given.
"""
import re
import sys


def comsub_end(s, i):
    """s[i:i+2] == '$(': index just past the matching ')' (correct parse)."""
    n, j, depth = len(s), i + 2, 1
    while j < n:
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == "'":
            k = s.find("'", j + 1)
            j = n if k < 0 else k + 1
            continue
        if c == '"':
            j = dq_end(s, j)
            continue
        if c == "`":
            k = j + 1
            while k < n and s[k] != "`":
                k += 2 if s[k] == "\\" else 1
            j = k + 1
            continue
        if c == "$" and s[j + 1:j + 2] == "(":
            j = comsub_end(s, j)
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    return n


def dq_end(s, i):
    """s[i] == '"': index just past the closing quote (correct parse)."""
    n, j = len(s), i + 1
    while j < n:
        c = s[j]
        if c == "\\":
            j += 2
            continue
        if c == '"':
            return j + 1
        if c == "$" and s[j + 1:j + 2] == "(":
            j = comsub_end(s, j)
            continue
        if c == "`":
            k = j + 1
            while k < n and s[k] != "`":
                k += 2 if s[k] == "\\" else 1
            j = k + 1
            continue
        j += 1
    return n


def gobble(t, i, satisfy):
    """bash 3.2 brace_gobbler: index of `satisfy` it stops at, or -1."""
    n, quoted, level, passc = len(t), "", 0, False
    while i < n:
        c = t[i]
        if passc:
            passc = False
            i += 1
            continue
        if c == "\\" and quoted in ("", '"', "`"):
            passc = True
            i += 1
            continue
        if c == "$" and t[i + 1:i + 2] == "{" and quoted != "'":
            passc = True
            if quoted == "":
                level += 1
            i += 1
            continue
        if quoted:
            if c == quoted:
                quoted = ""
            i += 1
            continue
        if c in "\"'`":
            quoted = c
            i += 1
            continue
        if c == "$" and t[i + 1:i + 2] == "(":
            i = comsub_end(t, i)
            continue
        if c == satisfy and level == 0:
            if c == "{" and (i == 0 or t[i - 1] in " \t\n") and (t[i + 1:i + 2] in (" ", "\t", "\n", "}")):
                i += 1
                continue
            return i
        if c == "{":
            level += 1
        elif c == "}" and level:
            level -= 1
        i += 1
    return -1


def expands(word):
    """True if bash 3.2 would brace-expand this word."""
    i = 0
    while True:
        o = gobble(word, i, "{")
        if o < 0:
            return False
        c = gobble(word, o + 1, "}")
        if c < 0:
            i = o + 1
            continue
        amble = word[o + 1:c]
        j = 0
        while j < len(amble):
            if amble[j] == "\\":
                j += 2
                continue
            if amble[j] == ",":
                return True
            j += 1
        if re.fullmatch(r"(-?\d+|[A-Za-z])\.\.(-?\d+|[A-Za-z])", amble):
            return True
        i = c + 1


def main(paths):
    hits = 0
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        for m in re.finditer(r'"\$\(', text):
            start = m.start()
            word = text[start:dq_end(text, start)]
            if expands(word):
                line = text.count("\n", 0, start) + 1
                first = word.splitlines()[0] if word else ""
                print(f"{path}:{line}: {first[:160]}")
                hits += 1
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
