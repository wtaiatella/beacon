#!/usr/bin/env bash
# Validate roadmap markdown: duplicate ROAD ids, orphan deps, cycles, stale status vs checkboxes.
# Scans the roadmap root directory (active *.md + completed/*.md). ROADMAP_FILE is the tree root.
# Implementation: Python 3 (embedded) for portability; Bash 3.2 cannot use associative arrays.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=roadmap-lib.sh
source "$(dirname "$0")/roadmap-lib.sh"

usage() {
  echo "Usage: $(basename "$0") [--file <dir> | --root <dir>] [--quiet]"
  echo "  Exits 0 if no errors (warnings still exit 0)."
  echo "  Exits 1 if any ERROR is reported."
  echo ""
  echo "  --file <dir>    Roadmap root directory (default: \$ROADMAP_FILE or docs/roadmaps under repo root)"
  echo "  --root <dir>    Same as --file (alias)"
  echo ""
  echo "Environment: ROADMAP_FILE — roadmap root directory (relative to repo root or absolute)."
}

FILE=""
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file | --root)
      FILE="${2:?}"
      shift 2
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FILE" ]]; then
  FILE="$(roadmap_default_root "$ROOT")"
elif [[ "${FILE}" != /* ]]; then
  FILE="${ROOT%/}/${FILE}"
fi

if [[ -f "$FILE" ]]; then
  echo "Error: roadmap path must be a directory (roadmap root), not a single file: $FILE" >&2
  echo "Set ROADMAP_FILE or --file/--root to the directory containing ROAD-NN-*.md (e.g. docs/roadmaps)." >&2
  exit 1
fi

if [[ ! -d "$FILE" ]]; then
  echo "Error: roadmap root not found: $FILE" >&2
  exit 1
fi

export ROADMAP_VALIDATE_ROOT="$FILE"
export ROADMAP_VALIDATE_QUIET="$QUIET"

exec python3 - "$@" <<'PY'
import os
import re
import sys
from collections import Counter, defaultdict

root = os.environ.get("ROADMAP_VALIDATE_ROOT", "")
quiet = os.environ.get("ROADMAP_VALIDATE_QUIET", "0") == "1"
if not root or not os.path.isdir(root):
    print("ERROR: roadmap root not found: %s" % root, file=sys.stderr)
    sys.exit(1)


def discover_md_paths(r: str):
    paths = []
    for name in sorted(os.listdir(r)):
        if not name.endswith(".md"):
            continue
        p = os.path.join(r, name)
        if os.path.isfile(p):
            paths.append(p)
    comp = os.path.join(r, "completed")
    if os.path.isdir(comp):
        for name in sorted(os.listdir(comp)):
            if not name.endswith(".md"):
                continue
            p = os.path.join(comp, name)
            if os.path.isfile(p):
                paths.append(p)
    return paths


road_header = re.compile(r"^###\s+ROAD-(\d+)\s*")
dep_ro = re.compile(r"ROAD-(\d+)")
status_re = re.compile(r"^\*\*Status:\*\*\s*(.*)$")
deliver_re = re.compile(r"^####\s+(Deliverables|Key\s+Deliverables)\s*$")
subhead_re = re.compile(r"^####\s+")
road_any = re.compile(r"^###\s+ROAD-")

entries = []  # list of dicts: id, status, unchecked, checked, deps, source


def parse_file(path: str):
    text = open(path, encoding="utf-8").read().splitlines()
    current = None
    in_deliverables = False

    def flush():
        nonlocal current
        if current is not None:
            entries.append(current)
            current = None

    for line in text:
        m = road_header.match(line)
        if m:
            flush()
            current = {
                "id": int(m.group(1)),
                "status": "",
                "unchecked": 0,
                "checked": 0,
                "deps": [],
                "source": path,
            }
            in_deliverables = False
            continue
        if current is None:
            continue
        if deliver_re.match(line):
            in_deliverables = True
            continue
        if subhead_re.match(line) or road_any.match(line):
            in_deliverables = False
        sm = status_re.match(line)
        if sm:
            current["status"] = sm.group(1).strip().lower()
        if line.startswith("**Dependencies:**"):
            for d in dep_ro.findall(line):
                current["deps"].append(int(d))
        if in_deliverables:
            if re.match(r"^-\s+\[\s*x\s*\]", line, re.I):
                current["checked"] += 1
            elif re.match(r"^-\s+\[\s*\]", line):
                current["unchecked"] += 1

    flush()


md_paths = discover_md_paths(root)
for p in md_paths:
    parse_file(p)

errors = 0
warnings = 0


def err(msg):
    global errors
    print("ERROR:", msg, file=sys.stderr)
    errors += 1


def warn(msg):
    global warnings
    print("WARN:", msg, file=sys.stderr)
    warnings += 1


# duplicate headers (union across all files)
ids = [e["id"] for e in entries]
for rid, c in Counter(ids).items():
    if c > 1:
        locs = sorted({e["source"] for e in entries if e["id"] == rid})
        err(
            "duplicate ### ROAD-%d header (%d times) in %s"
            % (rid, c, "; ".join(locs))
        )

idset = set(ids)

# orphan deps (resolved against union of all ROAD ids in the tree)
for e in entries:
    for d in e["deps"]:
        if d not in idset:
            err(
                "ROAD-%d (%s) depends on ROAD-%d, but ROAD-%d is not defined in the roadmap tree"
                % (e["id"], e["source"], d, d)
            )

# cycle: edges d -> r for "r depends on d"
edges = defaultdict(list)
for e in entries:
    for d in e["deps"]:
        if d in idset:
            edges[d].append(e["id"])

GRAY, BLACK = 1, 2
mark = {}


def dfs(u):
    mark[u] = GRAY
    for v in edges.get(u, []):
        mv = mark.get(v, 0)
        if mv == GRAY:
            err("circular ROAD dependency (reachable from ROAD-%d)" % u)
        elif mv != BLACK:
            dfs(v)
    mark[u] = BLACK


for n in idset:
    if mark.get(n, 0) == 0:
        dfs(n)

# stale status
for e in entries:
    st = e["status"]
    if "completed" in st and e["unchecked"] > 0:
        warn(
            "ROAD-%d (%s): Status suggests complete but %d unchecked deliverable(s)"
            % (e["id"], e["source"], e["unchecked"])
        )
    if ("planned" in st or "in progress" in st) and e["checked"] > 0 and e["unchecked"] == 0:
        warn(
            "ROAD-%d (%s): Status is Planned/In Progress but all deliverables look checked"
            % (e["id"], e["source"])
        )

if not quiet:
    print("Roadmap validation:", root)
    print("  Markdown files scanned:", len(md_paths))
    print("  ROAD entries:", len(idset))
    print("  Errors:", errors, " Warnings:", warnings)

sys.exit(1 if errors else 0)
PY
