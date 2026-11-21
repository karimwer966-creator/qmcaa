#!/usr/bin/env python3
"""Dependency/structure sanity checks for the QSMC MQL source tree.

This is deliberately not an MQL compiler. MetaEditor remains required for
platform syntax and API validation.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEARCH_ROOTS = (ROOT / "Include", ROOT / "Experts", ROOT / "Scripts", ROOT / "Tests")
SOURCE_SUFFIXES = {".mqh", ".mq5"}


def strip_comments_and_strings(source: str) -> str:
    """Preserve newlines while removing comments and quoted string contents."""
    out: list[str] = []
    i = 0
    state = "code"
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if state == "code":
            if ch == "/" and nxt == "/":
                state = "line_comment"
                out.extend("  ")
                i += 2
                continue
            if ch == "/" and nxt == "*":
                state = "block_comment"
                out.extend("  ")
                i += 2
                continue
            if ch == '"':
                state = "string"
                out.append(" ")
                i += 1
                continue
            if ch == "'":
                state = "char"
                out.append(" ")
                i += 1
                continue
            out.append(ch)
            i += 1
            continue
        if state == "line_comment":
            if ch == "\n":
                out.append("\n")
                state = "code"
            else:
                out.append(" ")
            i += 1
            continue
        if state == "block_comment":
            if ch == "*" and nxt == "/":
                out.extend("  ")
                state = "code"
                i += 2
            else:
                out.append("\n" if ch == "\n" else " ")
                i += 1
            continue
        if state in ("string", "char"):
            quote = '"' if state == "string" else "'"
            if ch == "\\":
                out.append(" ")
                if i + 1 < len(source):
                    out.append("\n" if source[i + 1] == "\n" else " ")
                    i += 2
                else:
                    i += 1
                continue
            if ch == quote:
                state = "code"
            out.append("\n" if ch == "\n" else " ")
            i += 1
    return "".join(out)


def resolve_include(source_file: Path, include: str) -> Path | None:
    candidates = (source_file.parent / include, ROOT / "Include" / include, ROOT / include)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    # Built-in MetaTrader library headers are supplied by the terminal.
    if include.startswith(("Trade/", "Arrays/", "Math/", "Graphics/")):
        return Path("<MT5-library>")
    return None


def main() -> int:
    files = [p for base in SEARCH_ROOTS for p in base.rglob("*")
             if p.is_file() and p.suffix in SOURCE_SUFFIXES]
    errors: list[str] = []
    for path in files:
        source = path.read_text(encoding="utf-8", errors="replace")
        if not source.strip():
            errors.append(f"empty source file: {path.relative_to(ROOT)}")
            continue
        if path.suffix == ".mqh":
            guard = re.search(r"^#ifndef\s+(\w+)", source, re.MULTILINE)
            define = re.search(r"^#define\s+(\w+)", source, re.MULTILINE)
            if not guard or not define or guard.group(1) != define.group(1):
                errors.append(f"missing/mismatched include guard: {path.relative_to(ROOT)}")

        for include in re.findall(r'#include\s+["<]([^">]+)[">]', source):
            if resolve_include(path, include) is None:
                errors.append(f"unresolved include {include}: {path.relative_to(ROOT)}")

        clean = strip_comments_and_strings(source)
        for opening, closing in (("(", ")"), ("{", "}"), ("[", "]")):
            depth = 0
            for line_no, line in enumerate(clean.splitlines(), 1):
                for character in line:
                    if character == opening:
                        depth += 1
                    elif character == closing:
                        depth -= 1
                        if depth < 0:
                            errors.append(f"extra {closing} at {path.relative_to(ROOT)}:{line_no}")
                            depth = 0
            if depth:
                errors.append(f"unbalanced {opening}{closing} in {path.relative_to(ROOT)}")

        # Live submission API is intentionally absent from this codebase.
        if re.search(r"\bOrderSend\s*\(", clean) or re.search(r"\bCTrade\b", clean):
            errors.append(f"live trade API reference: {path.relative_to(ROOT)}")

    print(f"QSMC static structure check: {len(files)} source files inspected")
    if errors:
        for error in errors:
            print("FAIL:", error)
        return 1
    print("PASS: source files non-empty; includes, guards and delimiters resolve.")
    print("NOTE: this check is not an MQL compiler or MetaTrader runtime test.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
