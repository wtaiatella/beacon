#!/usr/bin/env python3
"""
Read-only query over Cursor agent JSONL transcripts for a session.

Resolves PROJECT_HASH from docs/sessions/<session-id>/current.md (PROJECT_HASH anchor;
SESSION_START is present for parity with audit-session-trace / session memory but is not used
for time-window filtering here—see --help).

Discovers *.jsonl recursively under the transcript root, consistent with audit-session-trace.py:

  ~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/**/*.jsonl

Override the transcript directory for tests or CI with --transcript-root or QUERY_TRANSCRIPT_ROOT
(absolute or workspace-relative paths are resolved from --workspace-root).

Filters each JSON object line by message role (assistant / user / both) and optional --grep
(case-sensitive substring on extracted message text). Output is plain text with byte caps.

Exit status:
  0 — success (including empty result)
  1 — invalid args, path safety rejection, or unexpected I/O error
  2 — --strict: missing current.md, anchors, or transcript directory
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

# Match audit-session-trace.py caps for rendered payload.
DEFAULT_MAX_PER_FILE = 48 * 1024
DEFAULT_MAX_TOTAL = 384 * 1024

# Defense-in-depth: when no JSONL line matches role/grep, do not read to EOF (aligned with
# audit-session-trace.py forbid raw scan cap).
DEFAULT_MAX_SCAN_BYTES_NO_MATCH = 2 * 1024 * 1024
DEFAULT_MAX_SCAN_LINES_NO_MATCH = 500_000

# Skip json.loads on pathological single lines (memory bound).
DEFAULT_MAX_JSONL_LINE_CHARS = 512 * 1024

ANCHOR_SESSION = "SESSION_START:"
ANCHOR_PROJECT = "PROJECT_HASH:"

_SESSION_ID_RE = re.compile(
    r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z(?:-[a-z0-9._-]{1,64})?$"
)
_PROJECT_HASH_RE = re.compile(r"^[A-Za-z0-9._-]{1,512}$")

_ROLE_CHOICES = frozenset({"assistant", "user", "both"})


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
    if not session_id:
        return False, "empty session id"
    if ".." in session_id or "/" in session_id or "\\" in session_id:
        return False, "session id must not contain path separators or '..'"
    if not _SESSION_ID_RE.match(session_id):
        return False, "session id does not match expected pattern (see session-memory.sh)"
    return True, ""


def validate_project_hash(project_hash: str) -> tuple[bool, str]:
    if not project_hash:
        return False, "empty PROJECT_HASH"
    if ".." in project_hash or "/" in project_hash or "\\" in project_hash:
        return False, "PROJECT_HASH must not contain path separators or '..'"
    if not _PROJECT_HASH_RE.match(project_hash):
        return False, "PROJECT_HASH contains disallowed characters"
    return True, ""


def session_paths_under_repo(workspace: Path, session_id: str) -> tuple[Path, Path] | None:
    sessions_root = (workspace / "docs" / "sessions").resolve()
    try:
        session_dir = (sessions_root / session_id).resolve()
        session_dir.relative_to(sessions_root)
    except ValueError:
        return None
    return session_dir / "current.md", session_dir / "context-audit.log"


def transcript_root_default(home: Path, project_hash: str) -> Path:
    return home / ".cursor" / "projects" / project_hash / "agent-transcripts"


def extract_message_text(record: dict[str, Any]) -> str:
    """Best-effort text from a JSONL message object (OpenAI/Cursor-style)."""
    c = record.get("content")
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        parts: list[str] = []
        for p in c:
            if isinstance(p, dict):
                if p.get("type") == "text" and isinstance(p.get("text"), str):
                    parts.append(p["text"])
                elif isinstance(p.get("content"), str):
                    parts.append(p["content"])
            elif isinstance(p, str):
                parts.append(p)
        return "".join(parts)
    return ""


def role_matches(record_role: str | None, choice: str) -> bool:
    if not record_role:
        return False
    r = record_role.strip().lower()
    if choice == "both":
        return r in ("assistant", "user")
    return r == choice


def process_line(
    raw_line: str,
    line_no: int,
    role_choice: str,
    grep_sub: str | None,
    max_jsonl_line_chars: int,
) -> str | None:
    line = raw_line.strip()
    if not line:
        return None
    if len(line) > max_jsonl_line_chars:
        return None
    try:
        rec = json.loads(line)
    except json.JSONDecodeError:
        return None
    if not isinstance(rec, dict):
        return None
    role_val = rec.get("role")
    role_s = role_val if isinstance(role_val, str) else None
    if not role_matches(role_s, role_choice):
        return None
    text = extract_message_text(rec)
    if grep_sub is not None and grep_sub not in text:
        return None
    header = f"  line {line_no} role={role_s or '?'} ---"
    body = text if text else "(empty content)"
    return f"{header}\n{body}\n"


@dataclass
class Budget:
    max_per_file: int
    max_total: int
    used_total: int = 0

    def take(self, n: int) -> int:
        remain = self.max_total - self.used_total
        return max(0, min(n, remain))


def emit_file_block(
    path: Path,
    rel: Path,
    budget: Budget,
    role_choice: str,
    grep_sub: str | None,
    stderr: Any,
    *,
    max_jsonl_line_chars: int,
    max_scan_bytes_no_match: int,
    max_scan_lines_no_match: int,
) -> str:
    per_cap = budget.take(budget.max_per_file)
    if per_cap <= 0:
        return ""
    header = f"--- {rel.as_posix()} ({path.stat().st_size} bytes) ---\n"
    block = header
    emitted = 0
    bytes_seen_no_match = 0
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line_no, raw in enumerate(f, start=1):
                if emitted == 0:
                    bytes_seen_no_match += len(raw.encode("utf-8", errors="replace"))
                    if (
                        line_no > max_scan_lines_no_match
                        or bytes_seen_no_match > max_scan_bytes_no_match
                    ):
                        stderr.write(
                            "query-transcript: scan cap (no matching lines yet): "
                            f"stopped in {rel.as_posix()} after {line_no} line(s), "
                            f"{bytes_seen_no_match} bytes read (limits: "
                            f"{max_scan_lines_no_match} lines, {max_scan_bytes_no_match} bytes)\n"
                        )
                        break
                chunk = process_line(
                    raw, line_no, role_choice, grep_sub, max_jsonl_line_chars
                )
                if chunk is None:
                    continue
                emitted += 1
                cand = chunk
                if len(block) + len(cand) > per_cap:
                    block += f"  ... truncated (per-file byte cap after {emitted} matching line(s))\n"
                    break
                block += cand
    except OSError as e:
        stderr.write(f"query-transcript: read error {path}: {e}\n")
        return ""

    if emitted == 0:
        return ""

    chunk_len = len(block)
    allowed = budget.take(chunk_len)
    if allowed < len(block):
        block = block[:allowed] + "\n... [truncated to remaining total budget]\n"
    budget.used_total += len(block)
    return block


def resolve_transcript_root(
    workspace: Path,
    session_id: str,
    home: Path,
    override: Path | None,
) -> tuple[Path | None, str | None, str]:
    """
    Returns (transcript_root_path, error_message, kind).
    kind: "" ok, "fatal" invalid paths/validation, "soft" missing file/anchors/dir for strict mode.
    """
    paths = session_paths_under_repo(workspace, session_id)
    if paths is None:
        return None, "session paths resolve outside docs/sessions (rejected)", "fatal"

    current_md, _log = paths
    if not current_md.is_file():
        return None, f"missing {current_md}", "soft"

    text = current_md.read_text(encoding="utf-8", errors="replace")
    _ss, project_hash = parse_anchors(text)

    if override is not None:
        root = override.resolve()
        return root, None, ""

    if not project_hash:
        return (
            None,
            "PROJECT_HASH missing from current.md (need anchors to locate ~/.cursor/...)",
            "soft",
        )

    ok_ph, ph_err = validate_project_hash(project_hash)
    if not ok_ph:
        return None, f"invalid PROJECT_HASH: {ph_err}", "fatal"

    root = transcript_root_default(home, project_hash)
    return root, None, ""


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Query Cursor agent JSONL transcripts for a session (read-only). "
            "Uses PROJECT_HASH from docs/sessions/<id>/current.md unless --transcript-root is set."
        ),
        epilog=(
            "Transcript layout matches audit-session-trace.py: "
            "~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/**/*.jsonl. "
            "Override with --transcript-root or QUERY_TRANSCRIPT_ROOT (relative paths resolve "
            "from --workspace-root). "
            "SESSION_START in docs/sessions/<id>/current.md is not used for time filtering here "
            "(informational / parity with audit tooling); use audit-session-trace for mtime windows. "
            "Role filter applies to JSON objects with a string 'role' field; --grep is a "
            "case-sensitive substring match on extracted message text (content). "
            f"Default output caps: {DEFAULT_MAX_PER_FILE} bytes per file, "
            f"{DEFAULT_MAX_TOTAL} bytes total. "
            f"When no line matches role/grep yet, scanning stops after "
            f"{DEFAULT_MAX_SCAN_LINES_NO_MATCH} lines or {DEFAULT_MAX_SCAN_BYTES_NO_MATCH} bytes "
            f"read per file. JSONL lines longer than {DEFAULT_MAX_JSONL_LINE_CHARS} characters "
            "are skipped (not parsed)."
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
        required=True,
        help="Session id under docs/sessions/<id>/ (required)",
    )
    parser.add_argument(
        "--home",
        type=Path,
        default=None,
        help="Home directory for ~/.cursor (default: $HOME; ignored when --transcript-root is set)",
    )
    parser.add_argument(
        "--transcript-root",
        type=Path,
        default=None,
        help="Override transcript directory (skip ~/.cursor/projects/<hash>/agent-transcripts)",
    )
    parser.add_argument(
        "--role",
        choices=sorted(_ROLE_CHOICES),
        default="both",
        help="Include assistant and/or user JSONL message lines (default: both)",
    )
    parser.add_argument(
        "--grep",
        metavar="SUBSTRING",
        default=None,
        help="Case-sensitive substring filter on message text (optional)",
    )
    parser.add_argument(
        "--max-per-file",
        type=int,
        default=DEFAULT_MAX_PER_FILE,
        metavar="BYTES",
        help=f"Max output bytes per transcript file (default {DEFAULT_MAX_PER_FILE})",
    )
    parser.add_argument(
        "--max-total",
        type=int,
        default=DEFAULT_MAX_TOTAL,
        metavar="BYTES",
        help=f"Max output bytes overall (default {DEFAULT_MAX_TOTAL})",
    )
    parser.add_argument(
        "--max-scan-lines-no-match",
        type=int,
        default=DEFAULT_MAX_SCAN_LINES_NO_MATCH,
        metavar="N",
        help=(
            "Max lines to read per file while no JSONL line matches role/grep "
            f"(default {DEFAULT_MAX_SCAN_LINES_NO_MATCH})"
        ),
    )
    parser.add_argument(
        "--max-scan-bytes-no-match",
        type=int,
        default=DEFAULT_MAX_SCAN_BYTES_NO_MATCH,
        metavar="N",
        help=(
            "Max UTF-8 bytes to read per file while no line matches "
            f"(default {DEFAULT_MAX_SCAN_BYTES_NO_MATCH})"
        ),
    )
    parser.add_argument(
        "--max-jsonl-line-chars",
        type=int,
        default=DEFAULT_MAX_JSONL_LINE_CHARS,
        metavar="N",
        help=(
            "Skip JSONL lines longer than this many characters before parsing "
            f"(default {DEFAULT_MAX_JSONL_LINE_CHARS})"
        ),
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 2 if session current.md or anchors are missing, or transcript root is not a directory",
    )
    args = parser.parse_args(argv)

    script_dir = Path(__file__).resolve().parent
    workspace = (args.workspace_root or (script_dir / ".." / "..")).resolve()

    env_root = os.environ.get("QUERY_TRANSCRIPT_ROOT", "").strip()
    transcript_override: Path | None = args.transcript_root
    if transcript_override is None and env_root:
        transcript_override = Path(env_root)
    if transcript_override is not None and not transcript_override.is_absolute():
        transcript_override = (workspace / transcript_override).resolve()

    session_id = args.session_id.strip()
    ok_sid, sid_err = validate_session_id(session_id)
    if not ok_sid:
        print(f"query-transcript: invalid session id: {sid_err}", file=sys.stderr)
        return 1

    home = args.home or Path(os.environ.get("HOME", ""))
    if transcript_override is None:
        if not home or not home.is_dir():
            print("query-transcript: invalid or missing HOME; set --home", file=sys.stderr)
            return 1

    root, err, kind = resolve_transcript_root(workspace, session_id, home, transcript_override)
    if err:
        print(f"query-transcript: {err}", file=sys.stderr)
        if kind == "fatal":
            return 1
        # soft: missing current.md or PROJECT_HASH when using default ~/.cursor resolution
        if args.strict:
            return 2
        print("(no matching transcript content)", file=sys.stdout)
        return 0

    assert root is not None

    if not root.is_dir():
        print(f"query-transcript: transcript directory not found: {root}", file=sys.stderr)
        if args.strict:
            return 2
        print("(no matching transcript content)", file=sys.stdout)
        return 0

    try:
        jsonl_files = sorted(
            (p for p in root.rglob("*.jsonl") if p.is_file()),
            key=lambda p: str(p.relative_to(root)),
        )
    except OSError as e:
        print(f"query-transcript: list {root}: {e}", file=sys.stderr)
        return 1

    budget = Budget(max_per_file=args.max_per_file, max_total=args.max_total)
    chunks: list[str] = []
    for p in jsonl_files:
        rel = p.relative_to(root)
        chunk = emit_file_block(
            p,
            rel,
            budget,
            args.role,
            args.grep,
            sys.stderr,
            max_jsonl_line_chars=args.max_jsonl_line_chars,
            max_scan_bytes_no_match=args.max_scan_bytes_no_match,
            max_scan_lines_no_match=args.max_scan_lines_no_match,
        )
        if chunk:
            chunks.append(chunk)

    out = "\n".join(chunks) if chunks else "(no matching transcript content)\n"
    sys.stdout.write(out)
    if not out.endswith("\n"):
        sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
