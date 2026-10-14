#!/usr/bin/env python3
"""
Project-scoped session trace audit for orchestrated /run Finish.

Reads docs/sessions/<id>/current.md for SESSION_START and PROJECT_HASH, then recursively scans
~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/**/*.jsonl for files whose mtime (UTC) is
on or after an effective window start: SESSION_START parsed as UTC, minus a 60-second buffer
for IDE/file-creation lag before comparing to each file's mtime as a timezone-aware UTC datetime.

When no files match the time window (or the transcript directory is missing), emits diagnostic
metadata: all .jsonl under the primary transcript root (path relative to that root + mtime UTC),
plus a bounded scan of other ~/.cursor/projects/<hash>/agent-transcripts/ trees (see --help for caps).

Writes bounded metadata to docs/sessions/<id>/context-audit.log using an **append-only** policy:
each run adds one "Finish section" block with a UTC timestamp (see --help).

Exit status:
  0 — Successful run, including skip paths (missing dir, no anchors in non-strict, etc.)
  1 — Invalid --session-id / PROJECT_HASH (path safety), or unexpected I/O error
  2 — --strict: anchors missing, transcript dir missing, or (with --strict-empty) zero matching files
  3 — --exit-on-forbid: forbidden substring(s) matched in scoped transcript text (see --forbid-substrings)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable

# Default defense-in-depth caps (bytes of rendered payload text per run).
DEFAULT_MAX_PER_FILE = 48 * 1024
DEFAULT_MAX_TOTAL = 384 * 1024
SNIPPET_MAX = 240
PATH_STR_MAX = 512

# Raw read cap per JSONL for optional substring / role heuristics (forbid checks).
DEFAULT_FORBID_SCAN_MAX_BYTES = 2 * 1024 * 1024
PEEK_JSONL_MAX_LINES = 200

# Bounded sibling scan when primary hash yields zero matches (stderr + Finish payload; see --help).
SIBLING_SCAN_MAX_PROJECT_DIRS = 64
SIBLING_LIST_MAX_LINES = 24
SIBLING_STAT_BUDGET = 200

# Lines starting with this prefix identify SESSION_START / PROJECT_HASH (see docs/run-pipeline-reference.md).
ANCHOR_SESSION = "SESSION_START:"
ANCHOR_PROJECT = "PROJECT_HASH:"

# session-memory.sh: base id is YYYY-MM-DDTHHMMSSZ with optional -<slug> (sanitize_slug: kebab, max 64).
_SESSION_ID_RE = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z(?:-[a-z0-9._-]{1,64})?$"
)
# cursor-project-hash.sh: path-derived single segment (dots/slashes → hyphens).
_PROJECT_HASH_RE = re.compile(r"^[A-Za-z0-9._-]{1,512}$")

# Subtract from parsed SESSION_START (UTC) so transcripts created slightly before the anchor still match.
IDE_SESSION_START_BUFFER = timedelta(seconds=60)

# Heuristic path-like substrings inside JSON string values (bounded downstream).
UNIX_PATH = re.compile(r"/(?:[\w.-]+/)+[\w.-]+")
WIN_PATH = re.compile(r"[A-Za-z]:\\(?:[^\\/:]+\\)+[^\\/:]+")


def parse_session_start_iso(value: str) -> datetime:
    """Parse SESSION_START UTC value; supports ...Z and fractional seconds."""
    s = value.strip()
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt


def parse_anchors(text: str) -> tuple[str | None, str | None]:
    session_start: str | None = None
    project_hash: str | None = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith(ANCHOR_SESSION):
            session_start = line[len(ANCHOR_SESSION) :].strip()
        elif line.startswith(ANCHOR_PROJECT):
            project_hash = line[len(ANCHOR_PROJECT) :].strip()
    return session_start, project_hash


def validate_session_id(session_id: str) -> tuple[bool, str]:
    """Reject path segments that could escape docs/sessions/<id> (defense in depth)."""
    if not session_id:
        return False, "empty session id"
    if ".." in session_id or "/" in session_id or "\\" in session_id:
        return False, "session id must not contain path separators or '..'"
    if not _SESSION_ID_RE.match(session_id):
        return False, "session id does not match expected pattern (see session-memory.sh)"
    return True, ""


def validate_project_hash(project_hash: str) -> tuple[bool, str]:
    """Single path segment under ~/.cursor/projects/<hash>/; must match cursor-project-hash output."""
    if not project_hash:
        return False, "empty PROJECT_HASH"
    if ".." in project_hash or "/" in project_hash or "\\" in project_hash:
        return False, "PROJECT_HASH must not contain path separators or '..'"
    if not _PROJECT_HASH_RE.match(project_hash):
        return False, "PROJECT_HASH contains disallowed characters"
    return True, ""


def session_paths_under_repo(
    workspace: Path, session_id: str
) -> tuple[Path, Path] | None:
    """Resolve current.md and context-audit.log; return None if the session dir escapes sessions root."""
    sessions_root = (workspace / "docs" / "sessions").resolve()
    try:
        session_dir = (sessions_root / session_id).resolve()
        session_dir.relative_to(sessions_root)
    except ValueError:
        return None
    return session_dir / "current.md", session_dir / "context-audit.log"


def transcript_root(home: Path, project_hash: str) -> Path:
    return home / ".cursor" / "projects" / project_hash / "agent-transcripts"


def format_mtime_utc(path: Path) -> str:
    ts = path.stat().st_mtime
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def list_primary_jsonl_inventory(transcript_dir: Path) -> list[str]:
    """All .jsonl under transcript_dir recursively; each line: rel path + mtime (UTC)."""
    lines: list[str] = []
    if not transcript_dir.is_dir():
        return lines
    try:
        raw = [p for p in transcript_dir.rglob("*.jsonl") if p.is_file()]
    except OSError:
        return lines
    paths = sorted(raw, key=lambda p: str(p.relative_to(transcript_dir)))
    for p in paths:
        rel = p.relative_to(transcript_dir)
        try:
            lines.append(f"  {rel.as_posix()}  mtime_utc={format_mtime_utc(p)}")
        except OSError as e:
            lines.append(f"  {rel.as_posix()}  (stat error: {e})")
    return lines


def bounded_sibling_transcript_hits(
    home: Path,
    project_hash: str,
    window_start_utc: datetime,
) -> tuple[list[str], int]:
    """
    Other ~/.cursor/projects/<hash>/agent-transcripts/**/*.jsonl with mtime (UTC) >= effective window start.
    window_start_utc is SESSION_START (UTC-aware) minus IDE_SESSION_START_BUFFER.
    Returns (rendered lines, stat_calls_used). Caps: SIBLING_* constants.
    """
    projects = home / ".cursor" / "projects"
    out: list[str] = []
    stat_used = 0
    if not projects.is_dir():
        out.append("  (sibling scan skipped: ~/.cursor/projects not a directory)")
        return out, stat_used

    try:
        subdirs = [p for p in projects.iterdir() if p.is_dir() and p.name != project_hash]
    except OSError as e:
        out.append(f"  (sibling scan error listing projects: {e})")
        return out, stat_used

    def dir_mtime(p: Path) -> float:
        try:
            return p.stat().st_mtime
        except OSError:
            return 0.0

    subdirs.sort(key=dir_mtime, reverse=True)
    subdirs = subdirs[:SIBLING_SCAN_MAX_PROJECT_DIRS]

    for proj in subdirs:
        if len(out) >= SIBLING_LIST_MAX_LINES:
            break
        if stat_used >= SIBLING_STAT_BUDGET:
            break
        at = proj / "agent-transcripts"
        if not at.is_dir():
            continue
        try:
            jsonl_files = sorted(
                (p for p in at.rglob("*.jsonl") if p.is_file()),
                key=lambda p: str(p.relative_to(at)),
            )
        except OSError:
            continue
        for jp in jsonl_files:
            if len(out) >= SIBLING_LIST_MAX_LINES:
                break
            if stat_used >= SIBLING_STAT_BUDGET:
                break
            try:
                st = jp.stat()
            except OSError:
                stat_used += 1
                continue
            stat_used += 1
            file_mtime_utc = datetime.fromtimestamp(st.st_mtime, tz=timezone.utc)
            if file_mtime_utc >= window_start_utc:
                mu = format_mtime_utc(jp)
                rel = jp.relative_to(at).as_posix()
                out.append(
                    f"  project={proj.name!r}  file={rel!r}  mtime_utc={mu}"
                )

    if not out:
        out.append(
            "  (no other project dirs with .jsonl mtime >= effective window start within caps)"
        )
    return out, stat_used


def build_zero_match_diagnostics(
    home: Path,
    root: Path,
    project_hash: str,
    window_start_utc: datetime,
    *,
    root_exists: bool,
) -> str:
    blocks: list[str] = []
    blocks.append(
        "--- diagnostic: zero matches in SESSION_START window (after 60s IDE buffer) ---"
    )
    blocks.append(
        f"Caps: sibling_project_dirs<={SIBLING_SCAN_MAX_PROJECT_DIRS}, "
        f"sibling_lines<={SIBLING_LIST_MAX_LINES}, stat_calls<={SIBLING_STAT_BUDGET}"
    )
    blocks.append(f"Primary transcript root: {root}")
    if root_exists:
        inv = list_primary_jsonl_inventory(root)
        if inv:
            blocks.append(
                "All .jsonl under primary transcript root (recursive; rel path + mtime UTC):"
            )
            blocks.extend(inv)
        else:
            blocks.append("All .jsonl under primary transcript root: (none — empty or no *.jsonl)")
    else:
        blocks.append(
            "Primary transcript root: missing — cannot list .jsonl (check PROJECT_HASH path)"
        )

    sib_lines, stat_used = bounded_sibling_transcript_hits(
        home, project_hash, window_start_utc
    )
    blocks.append(
        "Other ~/.cursor/projects/<hash>/agent-transcripts/ "
        "(bounded; mtime UTC >= effective window start):"
    )
    blocks.extend(sib_lines)
    blocks.append(f"(sibling scan stat calls used: {stat_used})")
    blocks.append("--- end diagnostic ---")
    return "\n".join(blocks) + "\n"


def prior_session_hints_block(workspace: Path, active_session_id: str) -> str:
    """
    Newest other docs/sessions/<id>/current.md (by mtime) for hash-mismatch debugging.
    """
    sessions_root = workspace / "docs" / "sessions"
    candidates: list[tuple[float, str, Path]] = []
    if not sessions_root.is_dir():
        return "Prior session hints: (no docs/sessions directory)\n"
    try:
        for child in sessions_root.iterdir():
            if child.name == "ACTIVE_SESSION" or not child.is_dir():
                continue
            if child.name == active_session_id:
                continue
            cm = child / "current.md"
            if not cm.is_file():
                continue
            try:
                m = cm.stat().st_mtime
            except OSError:
                continue
            candidates.append((m, child.name, cm))
    except OSError as e:
        return f"Prior session hints: (error: {e})\n"
    if not candidates:
        return "Prior session hints: (no other session directories with current.md)\n"
    candidates.sort(key=lambda x: -x[0])
    _mtime, sid, cm_path = candidates[0]
    text = cm_path.read_text(encoding="utf-8", errors="replace")
    ss, ph = parse_anchors(text)
    return (
        f"Prior session hints (newest other session by current.md mtime): directory={sid}\n"
        f"  SESSION_START: {ss or '(missing)'}\n"
        f"  PROJECT_HASH: {ph or '(missing)'}\n"
    )


def truncate(s: str, max_len: int) -> str:
    if len(s) <= max_len:
        return s
    return s[: max_len - 3] + "..."


def collect_tokens(obj: Any, out: dict[str, int]) -> None:
    if isinstance(obj, dict):
        for k, v in obj.items():
            lk = str(k).lower()
            if lk == "usage" and isinstance(v, dict):
                for uk, uv in v.items():
                    ulk = str(uk).lower()
                    if "token" in ulk and isinstance(uv, (int, float)):
                        out[f"usage.{uk}"] = int(uv)
            elif "token" in lk and isinstance(v, (int, float)):
                out[str(k)] = int(v)
            elif isinstance(v, (dict, list)):
                collect_tokens(v, out)
    elif isinstance(obj, list):
        for item in obj:
            collect_tokens(item, out)


_SNIPPET_KEYS = frozenset(
    {
        "system",
        "systemprompt",
        "system_prompt",
        "instruction",
        "instructions",
        "systemreminder",
        "system_reminder",
    }
)


def collect_snippets(obj: Any, out: list[str], depth: int = 0) -> None:
    if depth > 40:
        return
    if isinstance(obj, dict):
        role = obj.get("role")
        for k, v in obj.items():
            lk = str(k).lower().replace("_", "")
            if isinstance(v, str) and v.strip():
                if lk in _SNIPPET_KEYS or (
                    lk == "content" and role == "system"
                ) or (
                    "prompt" in lk and "token" not in lk
                ):
                    out.append(truncate(v.strip(), SNIPPET_MAX))
            elif isinstance(v, (dict, list)):
                collect_snippets(v, out, depth + 1)
    elif isinstance(obj, list):
        for item in obj:
            collect_snippets(item, out, depth + 1)


def collect_paths(obj: Any, out: set[str], depth: int = 0) -> None:
    if depth > 40:
        return
    if isinstance(obj, str):
        for rx in (UNIX_PATH, WIN_PATH):
            for m in rx.finditer(obj):
                p = m.group(0)
                if len(p) >= 2:
                    out.add(truncate(p, PATH_STR_MAX))
    elif isinstance(obj, dict):
        for v in obj.values():
            collect_paths(v, out, depth + 1)
    elif isinstance(obj, list):
        for item in obj:
            collect_paths(item, out, depth + 1)


def summarize_line(line: str, line_no: int) -> str | None:
    line = line.strip()
    if not line:
        return None
    try:
        rec = json.loads(line)
    except json.JSONDecodeError as e:
        return f"  line {line_no}: [malformed JSON] {e.msg}"
    tokens: dict[str, int] = {}
    collect_tokens(rec, tokens)
    snippets: list[str] = []
    collect_snippets(rec, snippets)
    paths: set[str] = set()
    collect_paths(rec, paths)
    parts: list[str] = []
    if tokens:
        parts.append("tokens: " + ", ".join(f"{k}={v}" for k, v in sorted(tokens.items())))
    if snippets:
        dedup: list[str] = []
        seen: set[str] = set()
        for s in snippets:
            if s not in seen:
                seen.add(s)
                dedup.append(s)
        parts.append("snippets: " + " | ".join(dedup[:8]))
    if paths:
        plist = sorted(paths)[:40]
        parts.append("paths: " + ", ".join(plist))
    if not parts:
        parts.append("(no extracted token/snippet/path fields)")
    return f"  line {line_no}: " + "; ".join(parts)


@dataclass
class Budget:
    max_per_file: int
    max_total: int
    used_total: int = 0

    def take(self, n: int) -> int:
        """Return how many bytes we may still add (capped by remaining total)."""
        remain = self.max_total - self.used_total
        return max(0, min(n, remain))


def parse_forbid_substrings(raw: list[str] | None) -> list[str]:
    """Flatten --forbid-substrings values; each flag may be comma-separated."""
    if not raw:
        return []
    out: list[str] = []
    for chunk in raw:
        for part in chunk.split(","):
            s = part.strip()
            if s:
                out.append(s)
    return out


def normalize_jsonish_line(line: str) -> str:
    """Strip insignificant whitespace for cheap subagent_type detection."""
    return re.sub(r"\s+", "", line)


def peek_jsonl_subagent_type(path: Path, max_lines: int = PEEK_JSONL_MAX_LINES) -> str | None:
    """
    Best-effort: read the first JSON lines and return subagent_type if present.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for i, raw in enumerate(f):
                if i >= max_lines:
                    break
                line = raw.strip()
                if not line or not line.startswith("{"):
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if not isinstance(rec, dict):
                    continue
                for key in ("subagent_type", "subagentType", "agent", "agent_type", "agentType"):
                    v = rec.get(key)
                    if isinstance(v, str) and v.strip():
                        return v.strip().lower()
    except OSError:
        return None
    return None


def file_matches_agent_role(path: Path, transcript_root: Path, role: str) -> bool:
    """
    Heuristic: path segment, filename token, or JSONL metadata subagent_type.
    """
    role_l = role.lower().strip()
    if not role_l:
        return True
    try:
        rel = path.relative_to(transcript_root)
    except ValueError:
        rel = path
    parts_lower = [p.lower() for p in rel.parts]
    if role_l in parts_lower:
        return True
    name = path.name.lower()
    if name == f"{role_l}.jsonl":
        return True
    if name.startswith(f"{role_l}-") or name.startswith(f"{role_l}."):
        return True
    if f"-{role_l}-" in name:
        return True
    if name.endswith(f"-{role_l}.jsonl"):
        return True
    st = peek_jsonl_subagent_type(path)
    if st == role_l:
        return True
    # Embedded in JSON without parse (escaped quotes etc.)
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for i, raw in enumerate(f):
                if i >= PEEK_JSONL_MAX_LINES:
                    break
                compact = normalize_jsonish_line(raw)
                if f'"subagent_type":"{role_l}"' in compact:
                    return True
    except OSError:
        pass
    return False


def read_jsonl_raw_capped(path: Path, max_bytes: int) -> str:
    try:
        data = path.read_bytes()
    except OSError:
        return ""
    if len(data) <= max_bytes:
        return data.decode("utf-8", errors="replace")
    return data[:max_bytes].decode("utf-8", errors="replace")


def find_forbidden_substrings(text: str, patterns: list[str]) -> list[str]:
    """Return distinct patterns that appear as literal substrings in text."""
    hits: list[str] = []
    for p in patterns:
        if p and p in text:
            hits.append(p)
    return hits


def run_forbid_scan(
    selected: list[Path],
    transcript_root: Path,
    patterns: list[str],
    require_role: str | None,
    max_raw_bytes: int,
    stderr: Any,
) -> tuple[list[tuple[Path, str]], list[Path], list[Path]]:
    """
    Returns (matches as (path, pattern), files_scoped, files_skipped_role).
    """
    matches: list[tuple[Path, str]] = []
    scoped: list[Path] = []
    skipped: list[Path] = []
    role_l = require_role.lower().strip() if require_role else None
    uniq_patterns = list(dict.fromkeys(patterns))
    for path in selected:
        if role_l:
            if file_matches_agent_role(path, transcript_root, role_l):
                scoped.append(path)
            else:
                skipped.append(path)
                continue
        else:
            scoped.append(path)
    for path in scoped:
        raw = read_jsonl_raw_capped(path, max_raw_bytes)
        if len(raw) >= max_raw_bytes:
            stderr.write(
                f"audit-session-trace: forbid scan truncated at {max_raw_bytes} bytes: {path}\n"
            )
        for p in find_forbidden_substrings(raw, uniq_patterns):
            matches.append((path, p))
    return matches, scoped, skipped


def format_forbid_block(
    matches: list[tuple[Path, str]],
    scoped: list[Path],
    skipped: list[Path],
    *,
    transcript_root: Path,
    require_role: str | None,
) -> str:
    lines: list[str] = ["--- optional forbid check (raw JSONL substring scan) ---"]
    if require_role:
        lines.append(f"Agent role filter (heuristic): {require_role!r}")
    lines.append(f"Files scanned for forbid: {len(scoped)}")
    if skipped:
        lines.append(
            f"Files skipped (role filter): {len(skipped)} "
            f"(not matching --require-agent-role)"
        )
    if matches:
        lines.append("MATCHES (forbidden substring appears in scoped file text):")
        for path, pat in matches:
            try:
                rel = path.relative_to(transcript_root).as_posix()
            except ValueError:
                rel = path.as_posix()
            lines.append(f"  file={rel!r}  pattern={pat!r}")
    else:
        lines.append("MATCHES: (none)")
    lines.append("--- end forbid check ---")
    return "\n".join(lines) + "\n"


def process_jsonl(
    path: Path,
    budget: Budget,
    stderr: Any,
) -> str:
    per_cap = budget.take(budget.max_per_file)
    if per_cap <= 0:
        return ""
    header = f"--- {path.name} ({path.stat().st_size} bytes) ---\n"
    block = header
    line_no = 0
    malformed = 0
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for raw in f:
                line_no += 1
                summ = summarize_line(raw, line_no)
                if summ:
                    if "[malformed JSON]" in summ:
                        malformed += 1
                    cand = summ + "\n"
                    if len(block) + len(cand) > per_cap:
                        block += f"  ... truncated ({line_no} lines read; per-file cap)\n"
                        break
                    block += cand
    except OSError as e:
        stderr.write(f"audit-session-trace: read error {path}: {e}\n")
        return ""

    if line_no == 0:
        block += "  (empty file)\n"

    if malformed:
        stderr.write(
            f"audit-session-trace: {path.name}: {malformed} malformed JSON line(s)\n"
        )

    chunk_len = len(block)
    allowed = budget.take(chunk_len)
    if allowed < len(block):
        block = block[:allowed] + "\n... [truncated to remaining total budget]\n"
    budget.used_total += len(block)
    return block


def read_session_id(workspace: Path, explicit: str | None) -> str | None:
    if explicit:
        return explicit.strip() or None
    p = workspace / "docs" / "sessions" / "ACTIVE_SESSION"
    if not p.is_file():
        return None
    return p.read_text(encoding="utf-8", errors="replace").splitlines()[0].strip() or None


def ensure_log_banner(log_path: Path) -> None:
    if log_path.exists():
        return
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(
        "# context-audit.log — append-only Finish sections per run; see scripts/tools/audit-session-trace.py --help\n\n",
        encoding="utf-8",
    )


def append_finish_section(
    log_path: Path,
    body: str,
    *,
    finished_utc: str,
    session_id: str,
    status: str,
    meta_lines: Iterable[str],
) -> None:
    ensure_log_banner(log_path)
    sep = "=" * 80
    lines = [
        sep,
        "context-audit — Finish section (append-only; one block per invocation)",
        f"Finished (UTC): {finished_utc}",
        f"Session id: {session_id}",
        *meta_lines,
        "--- payload ---",
        body.rstrip(),
        "---",
        f"Status: {status}",
        sep,
        "",
    ]
    with open(log_path, "a", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Audit Cursor agent transcripts for the active session.",
        epilog=(
            "Time window: SESSION_START is parsed as UTC; files must have mtime (UTC) on or after "
            f"(SESSION_START minus a {int(IDE_SESSION_START_BUFFER.total_seconds())}s IDE buffer). "
            "Zero-match diagnostics: primary tree lists every *.jsonl recursively (path under "
            "agent-transcripts + mtime UTC); "
            "sibling scan considers other ~/.cursor/projects/<hash>/agent-transcripts/ with caps "
            f"(max {SIBLING_SCAN_MAX_PROJECT_DIRS} project dirs, "
            f"{SIBLING_LIST_MAX_LINES} report lines, {SIBLING_STAT_BUDGET} stat calls). "
            "Optional --forbid-substrings performs a literal substring scan on raw JSONL bytes "
            "(pair with --require-agent-role qa for LPP-style QA checks). Exit 3 only with "
            "--exit-on-forbid when a pattern matches. "
            "See docs/run-pipeline-reference.md (session trace audit)."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--workspace-root",
        type=Path,
        default=None,
        help="Repository root (default: parent of scripts/tools/)",
    )
    parser.add_argument(
        "--session-id",
        default=None,
        help="Deprecated. Ignored when --ticket is set.",
    )
    parser.add_argument(
        "--ticket",
        default=None,
        help="Workspace-relative ticket folder. Reads <ticket>/_run/timeline.md and writes <ticket>/_run/audit.log.",
    )
    parser.add_argument(
        "--home",
        type=Path,
        default=None,
        help="Home directory for ~/.cursor (default: $HOME)",
    )
    parser.add_argument(
        "--max-per-file",
        type=int,
        default=DEFAULT_MAX_PER_FILE,
        help=f"Max rendered bytes per JSONL file (default {DEFAULT_MAX_PER_FILE})",
    )
    parser.add_argument(
        "--max-total",
        type=int,
        default=DEFAULT_MAX_TOTAL,
        help=f"Max rendered bytes total payload (default {DEFAULT_MAX_TOTAL})",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 2 if anchors are missing, transcript dir missing, or no matching .jsonl files",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print payload to stdout only; do not write context-audit.log",
    )
    parser.add_argument(
        "--pre-audit-delay-seconds",
        type=float,
        default=0.0,
        metavar="N",
        help=(
            "Sleep N seconds before reading ~/.cursor transcript trees (default 0). "
            "Use at Finish (run-pipeline section 9) only if JSONL flush lag causes zero-match audits; keep default 0."
        ),
    )
    parser.add_argument(
        "--prior-session-hints",
        action="store_true",
        help=(
            "Append a short block from the newest other docs/sessions/*/current.md (by mtime) "
            "with that file's SESSION_START / PROJECT_HASH for hash-mismatch debugging."
        ),
    )
    parser.add_argument(
        "--forbid-substrings",
        action="append",
        metavar="PATTERN",
        default=None,
        help=(
            "Optional LPP-style check: if any literal substring appears in scoped JSONL raw text, "
            "report in context-audit.log (repeat flag or use comma-separated patterns). "
            "Pair with --require-agent-role to limit to one agent's transcript files (recommended for QA). "
            "Default run behavior is unchanged when omitted."
        ),
    )
    parser.add_argument(
        "--require-agent-role",
        metavar="ROLE",
        default=None,
        help=(
            "When set with --forbid-substrings, only scan .jsonl files that match this agent role "
            "heuristically (path/filename tokens or subagent_type in early JSON lines), e.g. qa."
        ),
    )
    parser.add_argument(
        "--forbid-scan-max-bytes",
        type=int,
        default=DEFAULT_FORBID_SCAN_MAX_BYTES,
        metavar="N",
        help=(
            f"Max bytes of each JSONL read for forbid substring scan (default {DEFAULT_FORBID_SCAN_MAX_BYTES})."
        ),
    )
    parser.add_argument(
        "--exit-on-forbid",
        action="store_true",
        help=(
            "If any --forbid-substrings pattern matches in scoped files, exit 3 after writing the log "
            "(default: still exit 0; violations are WARN in Status unless this flag is set)."
        ),
    )
    args = parser.parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    workspace = (args.workspace_root or (script_dir / ".." / "..")).resolve()

    home = args.home or Path(os.environ.get("HOME", ""))
    if not home or not home.is_dir():
        print("audit-session-trace: invalid or missing HOME; set --home", file=sys.stderr)
        return 1

    if args.ticket:
        raw = args.ticket.strip().strip("/")
        if not raw.startswith("docs/specs/") or ".." in raw.split("/"):
            print(f"audit-session-trace: --ticket must be under docs/specs/: {raw}", file=sys.stderr)
            return 1
        ticket_dir = (workspace / raw).resolve()
        try:
            ticket_dir.relative_to((workspace / "docs" / "specs").resolve())
        except ValueError:
            print("audit-session-trace: --ticket resolves outside docs/specs", file=sys.stderr)
            return 1
        current_md = ticket_dir / "_run" / "timeline.md"
        log_path = ticket_dir / "_run" / "audit.log"
        session_id = raw
    else:
        session_id = read_session_id(workspace, args.session_id)
        if not session_id:
            msg = "no ticket (pass --ticket docs/specs/...)"
            print(f"audit-session-trace: {msg}", file=sys.stderr)
            return 2 if args.strict else 0

        ok_sid, sid_err = validate_session_id(session_id)
        if not ok_sid:
            print(f"audit-session-trace: invalid session id: {sid_err}", file=sys.stderr)
            return 1

        paths = session_paths_under_repo(workspace, session_id)
        if paths is None:
            print(
                "audit-session-trace: session paths resolve outside docs/sessions (rejected)",
                file=sys.stderr,
            )
            return 1

        current_md, log_path = paths

    if not current_md.is_file():
        print(f"audit-session-trace: missing {current_md}", file=sys.stderr)
        if args.strict:
            return 2
        return 0

    text = current_md.read_text(encoding="utf-8", errors="replace")
    session_start_s, project_hash = parse_anchors(text)

    if project_hash:
        ok_ph, ph_err = validate_project_hash(project_hash)
        if not ok_ph:
            print(f"audit-session-trace: invalid PROJECT_HASH: {ph_err}", file=sys.stderr)
            return 1

    if not session_start_s or not project_hash:
        print(
            "audit-session-trace: SESSION_START and/or PROJECT_HASH missing from the run timeline",
            file=sys.stderr,
        )
        if args.strict:
            return 2
        finished = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        if not args.stdout:
            append_finish_section(
                log_path,
                "(no anchors; skipped)",
                finished_utc=finished,
                session_id=session_id,
                status="SKIPPED: missing SESSION_START or PROJECT_HASH",
                meta_lines=[],
            )
        return 0

    try:
        session_start = parse_session_start_iso(session_start_s)
        window_start_utc = session_start - IDE_SESSION_START_BUFFER
    except (ValueError, OSError) as e:
        print(f"audit-session-trace: bad SESSION_START value: {e!s}", file=sys.stderr)
        finished = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        if not args.stdout:
            append_finish_section(
                log_path,
                f"(skipped — could not parse SESSION_START)\n{e!s}",
                finished_utc=finished,
                session_id=session_id,
                status="SKIPPED: invalid SESSION_START",
                meta_lines=[f"Raw SESSION_START line value: {session_start_s!r}"],
            )
        if args.strict:
            return 2
        return 0

    if args.pre_audit_delay_seconds > 0:
        time.sleep(args.pre_audit_delay_seconds)

    root = transcript_root(home, project_hash)
    _eff = window_start_utc.astimezone(timezone.utc)
    _eff_label = _eff.isoformat(timespec="milliseconds").replace("+00:00", "Z")
    meta_lines = [
        f"SESSION_START: {session_start_s}",
        f"Effective window start (UTC, SESSION_START minus {int(IDE_SESSION_START_BUFFER.total_seconds())}s IDE buffer): {_eff_label}",
        f"PROJECT_HASH: {project_hash}",
        f"Transcript root: {root}",
    ]
    if args.prior_session_hints:
        meta_lines.append("Flags: --prior-session-hints")

    if not root.is_dir():
        print(
            f"audit-session-trace: transcript directory not found (skip): {root}",
            file=sys.stderr,
        )
        print(
            "audit-session-trace: zero matches / missing dir; diagnostics in Finish payload",
            file=sys.stderr,
        )
        finished = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        diag = build_zero_match_diagnostics(
            home, root, project_hash, window_start_utc, root_exists=False
        )
        body = f"(skipped — directory missing)\n{root}\n\n{diag}"
        if args.prior_session_hints:
            body += "\n" + prior_session_hints_block(workspace, session_id)
        if not args.stdout:
            append_finish_section(
                log_path,
                body,
                finished_utc=finished,
                session_id=session_id,
                status="SKIPPED: agent-transcripts directory missing",
                meta_lines=meta_lines,
            )
        else:
            print(body)
        if args.strict:
            return 2
        return 0

    try:
        jsonl_files = sorted(
            (p for p in root.rglob("*.jsonl") if p.is_file()),
            key=lambda p: str(p.relative_to(root)),
        )
    except OSError as e:
        print(f"audit-session-trace: list {root}: {e}", file=sys.stderr)
        jsonl_files = []
    selected: list[Path] = []
    for p in jsonl_files:
        try:
            st = p.stat()
            file_mtime_utc = datetime.fromtimestamp(st.st_mtime, tz=timezone.utc)
            if file_mtime_utc >= window_start_utc:
                selected.append(p)
        except OSError as e:
            print(f"audit-session-trace: stat {p}: {e}", file=sys.stderr)

    budget = Budget(max_per_file=args.max_per_file, max_total=args.max_total)
    chunks: list[str] = []
    for p in selected:
        chunk = process_jsonl(p, budget, sys.stderr)
        if chunk:
            chunks.append(chunk)

    payload = "\n".join(chunks) if chunks else "(no matching transcript lines or empty extraction)\n"
    if not selected:
        print(
            "audit-session-trace: zero matches in time window; diagnostics in Finish payload",
            file=sys.stderr,
        )
        diag = build_zero_match_diagnostics(
            home, root, project_hash, window_start_utc, root_exists=True
        )
        payload = (
            f"(no .jsonl files with mtime UTC >= effective window start)\n"
            f"Considered directory: {root}\n"
            f"Files present: {len(jsonl_files)} .jsonl recursive (all older than trace window or none)\n\n"
            f"{diag}"
        )

    if args.prior_session_hints:
        payload += "\n" + prior_session_hints_block(workspace, session_id)

    forbid_patterns = parse_forbid_substrings(args.forbid_substrings)
    forbid_matches: list[tuple[Path, str]] = []
    forbid_block = ""
    scoped: list[Path] = []
    skipped: list[Path] = []

    if forbid_patterns:
        if not args.require_agent_role:
            sys.stderr.write(
                "audit-session-trace: note: --forbid-substrings without --require-agent-role "
                "scans all JSONL files in the time window\n"
            )
        if not selected:
            forbid_block = (
                "--- optional forbid check (raw JSONL substring scan) ---\n"
                "No JSONL files in window; forbid scan skipped.\n"
                "--- end forbid check ---\n"
            )
        else:
            forbid_matches, scoped, skipped = run_forbid_scan(
                selected,
                root,
                forbid_patterns,
                args.require_agent_role,
                args.forbid_scan_max_bytes,
                sys.stderr,
            )
            forbid_block = format_forbid_block(
                forbid_matches,
                scoped,
                skipped,
                transcript_root=root,
                require_role=args.require_agent_role,
            )
        if args.require_agent_role and selected and not scoped:
            sys.stderr.write(
                "audit-session-trace: forbid scan: no files matched "
                f"--require-agent-role {args.require_agent_role!r}\n"
            )
        payload = payload.rstrip() + "\n\n" + forbid_block.rstrip() + "\n"

    finished = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    meta_extra = [
        f"JSONL files in window (mtime UTC >= effective start): {len(selected)}",
    ]
    if forbid_patterns:
        meta_extra.append(
            f"Forbid patterns ({len(forbid_patterns)}): "
            + ", ".join(repr(p) for p in forbid_patterns)
        )
        if args.require_agent_role:
            meta_extra.append(f"Forbid role filter (heuristic): {args.require_agent_role!r}")
        meta_extra.append(f"Forbid hits: {len(forbid_matches)}")

    base_status = "OK" if selected else "SKIPPED: no jsonl in time window"
    if forbid_patterns and forbid_matches:
        if args.exit_on_forbid:
            audit_status = "FAILED: forbidden substring(s) in scoped transcripts"
            forbid_exit = 3
        else:
            audit_status = f"WARN: forbidden substring(s) | {base_status}"
            forbid_exit = 0
    else:
        audit_status = base_status
        forbid_exit = 0

    if args.stdout:
        print(payload)
        if forbid_exit == 3:
            return 3
        if args.strict and not selected:
            return 2
        return 0

    append_finish_section(
        log_path,
        payload,
        finished_utc=finished,
        session_id=session_id,
        status=audit_status,
        meta_lines=meta_lines + meta_extra,
    )

    if forbid_exit == 3:
        return 3
    if args.strict and not selected:
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
