#!/usr/bin/env python3
"""Static checks for the KING PANEL MQL5 sources.

MetaEditor catches syntax; these catch the classes of defect that compile
cleanly and only show up as wrong pixels or wrong numbers at runtime:

  1. brace/paren/bracket balance     - a stray one shifts whole blocks
  2. UTF-8 BOM                       - MetaEditor needs it for CJK literals
  3. non-opaque colour literals      - alpha < 0xFF makes the panel
                                       see-through onto the chart
  4. LL() placeholder symmetry       - EN and CN format strings must take
                                       the same arguments in the same order
  5. StringFormat arity              - specifier count vs argument count

Usage:  python3 lint.py        (exit 1 when anything fails)
"""
import codecs
import glob
import os
import re
import sys

SRC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "KingPanel")
SPEC = re.compile(r"%[-+ #0]*[\d.]*(?:I64)?[dfsuxX]")
LL = re.compile(r'LL\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')


def split_args(s):
    """Split a top-level MQL5 argument list, respecting strings and nesting."""
    out, depth, cur, instr = [], 0, "", False
    i = 0
    while i < len(s):
        c = s[i]
        if instr:
            if c == "\\":
                cur += s[i:i + 2]
                i += 2
                continue
            if c == '"':
                instr = False
            cur += c
        elif c == '"':
            instr = True
            cur += c
        elif c in "([":
            depth += 1
            cur += c
        elif c in ")]":
            depth -= 1
            cur += c
        elif c == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += c
        i += 1
    if cur.strip():
        out.append(cur.strip())
    return out


def literal_of(expr):
    """Concatenated text of adjacent string literals in expr (LL -> EN side)."""
    if expr.startswith("LL("):
        inner = split_args(expr[3:expr.rfind(")")])
        expr = inner[0] if inner else ""
    return "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', expr))


def main():
    fails = []
    files = sorted(glob.glob(os.path.join(SRC_DIR, "*.mq5")) +
                   glob.glob(os.path.join(SRC_DIR, "*.mqh")))
    if not files:
        print(f"no sources under {SRC_DIR}")
        return 1

    for path in files:
        name = os.path.basename(path)
        raw = open(path, "rb").read()
        src = raw.decode("utf-8-sig")

        # 1. balance
        for a, b in (("{", "}"), ("(", ")"), ("[", "]")):
            if src.count(a) != src.count(b):
                fails.append(f"{name}: unbalanced {a}{b} "
                             f"({src.count(a)} vs {src.count(b)})")

        # 2. BOM
        if not raw.startswith(codecs.BOM_UTF8):
            open(path, "wb").write(codecs.BOM_UTF8 + raw)
            print(f"{name}: BOM added")

        # 3. opaque colours
        for m in re.finditer(r"0x[0-9A-Ea-e][0-9A-Fa-f]{7}", src):
            line = src[:m.start()].count("\n") + 1
            fails.append(f"{name}:{line}: non-opaque colour {m.group(0)} "
                         f"(panel would show the chart through it)")

        # 4. bilingual placeholder symmetry
        for m in LL.finditer(src):
            en = [x for x in SPEC.findall(m.group(1))]
            cn = [x for x in SPEC.findall(m.group(2))]
            if en != cn:
                line = src[:m.start()].count("\n") + 1
                fails.append(f"{name}:{line}: LL() placeholder mismatch "
                             f"EN{en} CN{cn}")

        # 5. StringFormat arity
        for m in re.finditer(r"StringFormat\s*\(", src):
            i, depth, instr = m.end(), 1, False
            while i < len(src) and depth:
                c = src[i]
                if instr:
                    if c == "\\":
                        i += 2
                        continue
                    if c == '"':
                        instr = False
                elif c == '"':
                    instr = True
                elif c == "(":
                    depth += 1
                elif c == ")":
                    depth -= 1
                i += 1
            args = split_args(src[m.end():i - 1])
            if not args:
                continue
            lit = literal_of(args[0])
            if not lit:
                continue
            if len(SPEC.findall(lit)) != len(args) - 1:
                line = src[:m.start()].count("\n") + 1
                fails.append(f"{name}:{line}: StringFormat takes "
                             f"{len(SPEC.findall(lit))} specifiers but "
                             f"{len(args) - 1} arguments")

    if fails:
        print("\n".join(fails))
        print(f"\n{len(fails)} problem(s)")
        return 1
    print(f"clean: {len(files)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
