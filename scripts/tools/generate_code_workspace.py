#!/usr/bin/env python3
"""Emit a Cursor/VS Code multi-root .code-workspace JSON (ROAD-48)."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser(
        description="Write session.code-workspace JSON with Orchestrator + Target folders and git.scanRepositories.",
    )
    p.add_argument(
        "orchestrator_root",
        help="Absolute path to the agentic-workspace (orchestrator) root",
    )
    p.add_argument(
        "target_root",
        help="Absolute path to the writable target repository root",
    )
    p.add_argument(
        "output_file",
        help="Path to the .code-workspace file to write",
    )
    args = p.parse_args()

    orch = Path(args.orchestrator_root).resolve()
    tgt = Path(args.target_root).resolve()
    out = Path(args.output_file)

    if not orch.is_dir():
        print(f"generate-code-workspace: not a directory: {orch}", file=sys.stderr)
        return 1
    if not tgt.is_dir():
        print(f"generate-code-workspace: not a directory: {tgt}", file=sys.stderr)
        return 1

    orch_s = str(orch)
    tgt_s = str(tgt)
    doc = {
        "folders": [
            {"name": "Orchestrator", "path": orch_s},
            {"name": "Target", "path": tgt_s},
        ],
        "settings": {"git.scanRepositories": [tgt_s]},
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"
    out.write_text(text, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
