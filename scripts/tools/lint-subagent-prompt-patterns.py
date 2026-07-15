#!/usr/bin/env python3
"""
ROAD-55: scan .cursor agent/skill markdown for instructional shell one-liners.

Forbidden substrings (outside fenced code blocks) unless exempt — see
lint-check.sh header for policy and CONTRIBUTING.md for allowlist usage.

Exemptions:
  - Lines inside markdown fenced blocks (``` ... ```).
  - Lines containing HTML: <!-- lint:allow-subagent-shell -->
  - Lines that only document first-party scripts (pipeline-finish, git-inspect,
    archive-roadmap, query-transcript, audit-session-trace).
  - Lines that are clearly prohibition / negation prose (do not, never, etc.).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

# Substrings that must not appear in instructional prose (case-sensitive where noted).
FORBIDDEN = (
    "python3 -c",
    "git mv",
    "git commit",
    "awk '{",
)

ALLOW_LINE = re.compile(r"lint:allow-subagent-shell")

# If the line mentions these, it is documenting allowed tooling / finish path — allow.
PATH_EXEMPT = (
    "pipeline-finish",
    "git-inspect.sh",
    "archive-roadmap.sh",
    "query-transcript.py",
    "audit-session-trace",
)

# Whole-line prohibition / negation prose (forbid rogue patterns by name).
PROSE_NEGATION = re.compile(
    r"(?i)(do\s*\*\*not\*\*|"
    r"\bdo not\b|"
    r"don\x27t|"
    r"\bnever\b|"
    r"\bmust not\b|"
    r"\bno autonomous\b|"
    r"\bforbid\b|"
    r"not\s+use\s+inline|"
    r"not\s+use\s+raw|"
    r"\bnot\s+raw\b|"
    r"outside\s+the\s+script)"
)


def iter_markdown_files(root: Path) -> list[Path]:
    out: list[Path] = []
    agents = root / ".cursor" / "agents"
    skills = root / ".cursor" / "skills"
    if agents.is_dir():
        out.extend(sorted(agents.glob("*.md")))
    if skills.is_dir():
        out.extend(sorted(skills.rglob("*.md")))
    return out


def line_exempt_prose(line: str) -> bool:
    if ALLOW_LINE.search(line):
        return True
    if any(p in line for p in PATH_EXEMPT):
        return True
    if PROSE_NEGATION.search(line):
        return True
    return False


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return list of (line_no, line, forbidden_substring)."""
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    in_fence = False
    hits: list[tuple[int, str, str]] = []

    for i, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if line_exempt_prose(line):
            continue
        for sub in FORBIDDEN:
            if sub in line:
                hits.append((i, line, sub))
                break
    return hits


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: lint-subagent-prompt-patterns.py <repo-root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    if not root.is_dir():
        print(f"Error: not a directory: {root}", file=sys.stderr)
        return 2

    bad: list[tuple[Path, int, str, str]] = []
    for md in iter_markdown_files(root):
        for line_no, line, sub in scan_file(md):
            bad.append((md, line_no, line, sub))

    if not bad:
        return 0

    print(
        "Error: Forbidden subagent shell patterns in .cursor/agents/*.md or "
        ".cursor/skills/**/*.md (ROAD-55).",
        file=sys.stderr,
    )
    print(
        "Use fenced blocks for examples, <!-- lint:allow-subagent-shell --> on a line, "
        "or prohibition/first-party script wording — see scripts/tools/lint-check.sh.",
        file=sys.stderr,
    )
    for md, line_no, line, sub in bad:
        try:
            rel = md.relative_to(root)
        except ValueError:
            rel = md
        print(f"{rel}:{line_no}: ({sub}) {line[:200]}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
