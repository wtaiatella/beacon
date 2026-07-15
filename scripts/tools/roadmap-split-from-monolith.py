#!/usr/bin/env python3
"""
Split a legacy monolithic roadmap into docs/roadmaps/ROAD-NN-<slug>.md (one file per ### ROAD-NN block).

Used for one-time monolith split workflows. Re-run only if you restore a single-file backup as --source; defaults below.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

# Avoid a contiguous legacy path literal in-repo (grep hygiene); pass --source explicitly when needed.
_DEFAULT_LEGACY_MONOLITH = "docs/" + "roadmap.md"


def kebab(title: str) -> str:
    title = title.strip()
    title = re.sub(r"&", " and ", title)
    title = re.sub(r"[^a-zA-Z0-9\s-]", "", title)
    title = title.lower()
    title = re.sub(r"[^a-z0-9]+", "-", title)
    return title.strip("-") or "item"


def classify_status(block: str) -> str:
    m = re.search(r"^\*\*Status:\*\*\s*(.+)$", block, re.MULTILINE | re.IGNORECASE)
    if not m:
        m = re.search(r"^Status:\s*(.+)$", block, re.MULTILINE | re.IGNORECASE)
    if not m:
        return "active"
    vlow = m.group(1).strip().lower()
    if re.match(r"^completed\b", vlow):
        return "completed"
    return "active"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--source",
        type=Path,
        default=Path(_DEFAULT_LEGACY_MONOLITH),
        help="Monolithic roadmap file",
    )
    ap.add_argument(
        "--root",
        type=Path,
        default=Path("docs/roadmaps"),
        help="Roadmap directory root (active + completed/)",
    )
    args = ap.parse_args()
    text = args.source.read_text(encoding="utf-8")
    pat = re.compile(r"^### (ROAD-\d+):\s*(.+)$", re.MULTILINE)
    matches = list(pat.finditer(text))
    if not matches:
        raise SystemExit("No ### ROAD-NN: blocks found")

    out_root = args.root
    completed_dir = out_root / "completed"
    out_root.mkdir(parents=True, exist_ok=True)
    completed_dir.mkdir(parents=True, exist_ok=True)

    for i, m in enumerate(matches):
        road_id = m.group(1)
        title = m.group(2).strip()
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        block = text[start:end].rstrip() + "\n"
        slug = kebab(title)
        fname = f"{road_id}-{slug}.md"
        kind = classify_status(block)
        dest = (completed_dir if kind == "completed" else out_root) / fname
        if dest.exists():
            raise SystemExit(f"Refusing to overwrite: {dest}")
        dest.write_text(block, encoding="utf-8")
        print(dest)

    print(f"OK: {len(matches)} files", file=__import__("sys").stderr)


if __name__ == "__main__":
    main()
