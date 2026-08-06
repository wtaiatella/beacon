# /run Pipeline Reference

Detailed reference for **orchestrated mode** when the user types **`/run`**. The **main session agent** follows `.cursor/skills/run-pipeline/SKILL.md` (triggered by `.cursor/rules/run-pipeline-trigger.mdc`). This doc is for **human developers** — keep the **skill** authoritative for step order and gates.

## Per-phase gates (mandatory)

For specs with **`### Phase 1:`** … **`### Phase N:`** (or a single implicit phase when there are no phase headings):

1. After phase *k*’s **§ 5** implementation **`Task(dev|sre|data)`** batch completes, run **§ 6** — domain **`*-reviewer`** as needed **then** **`Task(scrum)`** — **before** any **§ 5** for phase *k+1*.
2. **Never** chain back-to-back implementation **`Task`** calls across phases without **§ 6** in between; that is **orchestration failure**.
3. **Never** delegate one **`Task(dev|sre|data)`** whose prompt spans **more than one** phase block.
4. **`Task(scrum)`** **PROCEED** authorizes the orchestrator to treat the phase as complete and to delegate **`Task(do)`** to **apply spec progress** from persona **Proposed completions** (single **`docs/specs/...-spec.md`** file — see skill **Task(do) for authorized spec updates**; personas **do not** edit spec checkboxes or frontmatter under **`[DELEGATION MODE: orchestrated]`**). The same **scrum authority** applies to **plan-segment** completion and to **§ 7.1** post-QA completion (see skill **§ 3–4**, **§ 7.1**).
5. **`--skip impl-review`** in **`/run`** is the optional escape hatch to skip **§ 6**; skipping **§ 6** without that flag (or equivalent explicit user intent) is **invalid completion**.
6. Skipping **§ 7.1** (**final `Task(scrum)`** after **`Task(qa)`**) when QA ran is **invalid** unless documented as **degraded** (see skill **Invalid completion**).

**Session file conventions (implementation):** After each **`Task(dev|sre|data)`** is **scheduled** in **§ 5**, the orchestrator appends **`impl | START | …`**; after that phase’s **§ 5** batch **completes**, **`impl | DONE | …`**. After **§ 6** (**`*-reviewer`** + **`Task(scrum)`**) for the segment, append **`impl-review | GATE | <score>% | <decision> | …`**. After each phase’s **§ 6** completes, the orchestrator still persists **`GATE: impl | DONE`** (with **`| phase: k |`** when the spec uses **`### Phase k:`**) — that line remains the **`--resume`** checkpoint; granular lines supplement the timeline. Authoritative formats, **`--resume`** interpretation, and multi-phase examples live in **`.cursor/skills/run-pipeline/SKILL.md`** — **Interaction with `--resume`** and **§ 5–§ 6** (checkpoint **`GATE: impl | DONE`** after **`Task(scrum)`** **PROCEED**, not after **§ 5** alone).

## Plan segment self-heal (§ 3–4)

Before implementation, **`Task(plan)`** and **`Task(plan-reviewer)`** may iterate up to **`--max-plan-iterations`** (default **3**). Authoritative procedure: **`.cursor/skills/run-pipeline/SKILL.md`** (**§ 3–4**), **Minimal context chain**, **Scrum authority and spec `status`**.

**Context slicing (plan segment):** On each plan-review miss (until acceptance or cap), the orchestrator **persists** **`PLAN_REVIEW_FEEDBACK:`** to **`docs/sessions/<id>/current.md`** via **`session-memory.sh write`**, then re-invokes **`Task(plan)`** with a **`Plan segment feedback:`** block derived **only** from that line **plus** **`Task(plan-reviewer)`** findings — **not** from replaying the full prior **`Task(plan)`** transcript, prior-turn chat history, or redundant **raw** pre-plan specialist logs. **`Pre-plan context:`** on amendment attempts stays **condensed** (same class as **`pre-plan/merged-brief.md`**). Optionally prefix with **one line** of metadata (attempt number, spec path, prior reviewer score) when it disambiguates the loop; scores **never** replace the sliced feedback block.

**`REQUEST_MAIN:` and explorer:** If **`Task(plan)`** returns **`REQUEST_MAIN: codebase-explorer <target-dir>`**, **only** the main session schedules **`Task(codebase-explorer)`**, **writes** a **bounded** Markdown report under **`docs/sessions/<id>/artifacts/explorer/`** (canonical; unique filename when multiple scouts occur in one run). **`session-memory.sh write`** trace (e.g. **`EXPLORATION:`**), then re-invoke **`Task(plan)`** with the **on-disk path** and optional **short excerpt** per **Minimal context chain** — **`/plan` must not** nest **`Task(codebase-explorer)`**. Same persist-and-re-feed pattern applies when **`Task(fix)`** returns the same **`REQUEST_MAIN`** (re-invoke **`Task(fix)`**). Authoritative procedure: **`.cursor/skills/run-pipeline/SKILL.md`** — **§ 3** **Exploration escalation**, **Least-privilege matrix**, **§ 5** **Mid-run enterprise context** ( **`codebase-explorer`** is **not** **`Task(mcp-*)`** ). See **`.cursor/agents/plan.md`** and the skill **Anti‑patterns**.

**Loop cap:** When inner-loop attempts reach **`--max-plan-iterations`** and the draft still fails plan-review thresholds, **do not** start another automatic iteration — use **`AskQuestion`** (or the same three-way chat fallback as elsewhere: Proceed anyway / Abort / Provide guidance) and record **`ESCALATION: plan-segment | max iterations`** in **`current.md`**.

**Scrum-only spec writes:** After the plan inner loop succeeds (or a documented human override), **`Task(scrum)`** runs for the plan gate. Under **`[DELEGATION MODE: orchestrated]`**, **`Task(do)`** applies **`docs/specs/*`** **`[x]`** / **`status`** / **`last-updated`** **only** after **`Task(scrum)`** **PROCEED**, from persona **Proposed spec updates** — same authority model as implementation segments (main session **must not** patch specs directly).

See **`.cursor/skills/run-pipeline/SKILL.md`** (**Non‑negotiables**, **§ 5 Mandatory sequence**, **§ 6**, **§ 7.1**, **Invalid completion**).

## Orchestration model (honest)

| Mechanism | Role |
|-----------|------|
| **run-pipeline skill** | Step-by-step workflow: flags, branch consent, worktrees, `Task` delegations, session-memory gates, completion template |
| **00-workspace-router.mdc** | Workspace identity, confidence thresholds, anti-fallback (main agent must not “finish” the pipeline by implementing product work inline) |
| **Session memory** | Persisted **`GATE:`** / **`FAILURE:`** lines for **`--resume`** (plan done, **`GATE: impl | DONE`** with optional **phase** index, final-scrum — exact strings in **`.cursor/skills/run-pipeline/SKILL.md`**, **Interaction with `--resume`** and **§ 6**). Granular **§ 5–§ 6** telemetry (**`impl | START`**, **`impl | DONE`**, **`impl-review | GATE | …`**) is append-only context for timelines and tooling — see the skill **§ 5** / **§ 6**. **§ 9 Finish:** when **`AskQuestion`** is available, **tool-first** Finish prompts (no pasted A–E / commit-push-MR walls as the primary path); **`PIPELINE: COMPLETE`** last — see the skill **§ 9**. |
| **apply-models.sh** | Snapshot / per-step overrides / restore; manual model mode skips per-step overrides |
| **Worktrees + human review** | Isolation in **working repos**; user approves merges — not automatic |

Cursor hooks **do not** reliably block tools for a dedicated orchestrator subagent; the previous `/run` + `run-exec` + watchdog stack was removed in favor of **main-agent orchestration** with explicit instructions.

## Session storage

Session memory lives under **`docs/sessions/`** (gitignored). Layout:

| Path | Purpose |
|------|---------|
| **`docs/sessions/ACTIVE_SESSION`** | One line, plain text: the active **session id** (no symlink — portable across Windows/macOS/Linux). |
| **`docs/sessions/<session-id>/current.md`** | Ephemeral scratch file: **`## Timeline`** holds all pipeline **`session-memory.sh write`** lines in **append order** (DECISION / QUESTION / **`GATE:`** bullets, **`impl | START`** / **`impl | DONE`**, **`impl-review | GATE | …`**, trace anchors, Finish lines). Legacy sessions may still contain older section headers above **`## Timeline`**. |
| **`docs/sessions/<session-id>/pre-plan/merged-brief.md`** | **Merged external brief** after pre-plan merge steps (bounded text — not raw unlimited tool dumps). Written by the orchestrator when pre-plan runs. |
| **`docs/sessions/<session-id>/pre-plan/specialists/{glean,arc,jira,confluence,gitlab}.md`** | **Per-specialist snapshot** for each **`Task(mcp-*)`** that actually ran in that **pre-plan** wave. Omit files for specialists that were not invoked. |
| **`docs/sessions/<session-id>/pre-plan/specialists/`** (mid-run) | **Same directory** as pre-plan handoffs. **Mid-run** orchestrator **`Task(mcp-*)`** results after **enterprise** **`REQUEST_MAIN:`** / enterprise **`QUESTION:`** (see skill **§ 5** — Mid-run enterprise context) are stored here with **distinct** filenames so they **do not** overwrite pre-plan **`glean.md`**, **`jira.md`**, etc. — e.g. **`jira-request-<timestamp>.md`**, **`mid-run/jira-001.md`**, **`arc-midrun-001.md`**. Authoritative behavior: **`docs/specs/2026-04-11-road-47-mcp-decoupling-spec.md`**. **`REQUEST_MAIN: codebase-explorer`** persists under **`artifacts/explorer/`** — **not** this tree. |
| **`docs/sessions/<session-id>/artifacts/explorer/`** | **Canonical** on-demand directory scout output (**`Task(codebase-explorer)`**) after **`REQUEST_MAIN: codebase-explorer <target-dir>`** from **`Task(plan)`**, **`Task(fix)`**, etc. One **bounded** `.md` per scout (unique name if repeated). Orchestrator **must** persist to disk before re-delegating; trace line in **`current.md`** (e.g. **`EXPLORATION:`**). Skill: **`.cursor/skills/run-pipeline/SKILL.md`** — **§ 3**, **Least-privilege matrix**, **§ 5**. |
| **`docs/sessions/<session-id>/artifacts/`** | **ROAD-51** bounded namespaces for orchestrator-injected prompts. Created by **`session-memory.sh`** (**`ensure_artifacts_dirs`**) on **`begin-run`** / **`new-session`**, on **`init`** when the active session dir exists, and when resolving a session for **`write`**. Subdirs: **`mcp-briefs/`** (scaffold — **single writer** for MCP brief **content** is **`pre-plan/`**; **no** duplicate full merges), **`explorer/`**, **`scanners/`**, **`diffs/dev/`**, **`diffs/sre/`**, **`diffs/data/`**, **`diffs/plan/`**. |
| **`docs/sessions/<session-id>/artifacts/scanners/`** | **Canonical QA prep wave (§ 7.0):** reports from parallel **`Task(spec-validator)`** and **`Task(security-scanner)`** **before** **`Task(qa)`**. **Filenames:** **`spec-validator.md`**, **`security-scanner.md`** (suffixed only if multiple runs require disambiguation). Skill: **`.cursor/skills/run-pipeline/SKILL.md`** — **§ 7.0**. Skipped when **`--skip qa`**. |
| **`docs/sessions/README.md`** | Tracked conventions (parent folder is otherwise gitignored); points at **`artifacts/`** tree above and **Local auditing** here. |

**Session id** is UTC **`YYYY-MM-DDTHHMMSSZ`** (time digits without colons), optionally suffixed with **`-<slug>`** (kebab-case) when created via **`session-memory.sh new-session my-slug`** or **`session-memory.sh begin-run my-slug`**.

**Pointer strategy:** The canonical active session is **`ACTIVE_SESSION`** at **`docs/sessions/ACTIVE_SESSION`**, not a symlink to **`current.md`**. Scripts resolve **`docs/sessions/<id>/current.md`** from that id. Legacy flat **`docs/sessions/current.md`** is migrated automatically on first use to a new timestamped directory.

**Per-`/run` folder rotation:** A **new** top-level session directory for each **`/run`** that does **not** use **`--resume`** is enforced in **`.cursor/skills/run-pipeline/SKILL.md`** **§2 Init** via **`scripts/hooks/pipeline-init.sh`**, which calls **`session-memory.sh begin-run`** (or equivalent) **before** pre-plan writes so **`pre-plan/merged-brief.md`** and related files land under a **fresh** **`docs/sessions/<id>/`**. **`--resume`** **skips** rotation and continues with the existing **`ACTIVE_SESSION`** and **`current.md`** (see the skill, **Interaction with `--resume`**).

**Hook vs pipeline (`init` vs `begin-run` / `pipeline-init.sh`):** **`scripts/tools/session-memory.sh init`** reuses a valid **`ACTIVE_SESSION`** when its directory still exists — correct for **`.cursor/hooks/session-init.sh`** (prune, then **`init`**), so opening the editor does **not** allocate a new id every time. Orchestrated **`/run`** **§2 Init** uses **`scripts/hooks/pipeline-init.sh`** (which invokes **`begin-run`** / **`write-trace-anchors`** / **`apply-models.sh --snapshot`** / **`session-memory.sh read`** in one bundle). See comments at the top of **`session-memory.sh`** and **`pipeline-init.sh --help`**.

### Orchestrator shell wrappers (API / stdout contracts)

Normative paths (workspace root). The **skill** forbids chained Shell, inline **`python3 -c`**, and raw **`git`** for probes — use these scripts (**`.cursor/skills/run-pipeline/SKILL.md`** — **Non‑negotiables** item **10**).

| Script | Role | Stdout contract |
|--------|------|-----------------|
| **`scripts/hooks/pipeline-init.sh`** | **§2 Init** | **Section headers** on stdout: **`=== pipeline-init ===`**, **`=== flags ===`**, **`=== session-rotation ===`**, **`=== trace-anchors ===`** (then **`write-trace-anchors: ok`**, **`trace-hash-root:`** *absolute path* — same root **`cursor-project-hash.sh`** uses for **`PROJECT_HASH`**; ROAD-48 when **`attach-target.txt`** is present), **`=== model-mode ===`** ( **`apply-models.sh --show-source`** output ), **`=== apply-models-snapshot ===`**, **`=== session-memory-read ===`** (tail of **`session-memory read`** ), **`=== knowledge-sources ===`** (**`arc-declared-in-mcp-json:`** `0|1`, local KB lines), **`=== pipeline-init-status ===`** / **`ok`**. Exit **non-zero** on hard failures (`begin-run`, **`write-trace-anchors`**, **`apply-models --snapshot`**, optional **`KNOWLEDGE_SOURCES` write`). Flags: **`--resume`**, **`--slug`**, **`--targets <dir> ...`**. |
| **`scripts/tools/git-inspect.sh`** | **§1** read-only | **Section headers:** **`=== git-inspect ===`**, **`=== repo ===`** (**`root:`**, **`branch:`**), **`=== path-scope ===`**, **`=== status ===`**, **`=== porcelain ===`**, **`=== untracked-sample ===`**, **`=== ignore-check ===`**, **`=== diff-stat (unstaged|staged) ===`**, **`=== git-inspect-done ===`**. Default: orchestrator repo at workspace root. **`--repo <dir>`** runs all git probes in that working tree (ROAD-48 **target** for branch consent when **`attach-target.txt`** is set). |
| **`scripts/tools/log-gate.sh`** | **`GATE:`** / telemetry | Subcommands write via **`session-memory.sh write`**; **no** structured stdout contract beyond errors — see **`log-gate.sh --help`**. |
| **`scripts/hooks/pipeline-finish.sh`** | **§9 Finish** | Human-readable sections: **`=== pipeline-finish ===`**, **`=== git-status (brief) ===`**, **`=== commit ===`** / **`=== git-add-commit ===`**, **`=== git-push ===`**, **`=== audit-session-trace ===`**, **`=== pipeline-finish-done (audit exit N) ===`**. Runs **`python3 scripts/tools/audit-session-trace.py`** internally — orchestrator **must not** invoke that Python entry separately. Flags: **`--no-commit`**, **`--commit-message`**, **`--commit-file`**, **`--push true|false`**, **`--pre-audit-delay-seconds`**, then **`--`** for extra audit args. |

**Lifecycle:** **`scripts/tools/session-memory.sh`** — **`read`**, **`write`**, **`clear`**, **`prune`**, **`init`** (hook: after **`prune`**; **reuses** valid active id; ensures **`artifacts/`** dirs when the session root exists), **`begin-run [slug]`** (pipeline: **new** id per non-resume **`/run`**; creates **`artifacts/*`** scaffold), **`new-session [slug]`** (same allocation as **`begin-run`**), **`active-path`**, **`session-root`**, **`write-trace-anchors [--resume]`** (see **Session trace anchors** below), **`trace-hash-root`** (prints the absolute path used for **`PROJECT_HASH`** — orchestrator root or **`attach-target.txt`** target). The session-init hook injects **Session ID** and the workspace-relative path to **`current.md`** when available.

### Session trace anchors

Orchestrated **`/run`** writes **trace anchors** into the active **`current.md`** so **`scripts/tools/audit-session-trace.py`** (Finish audit) can correlate **only** the correct **`~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`** tree and bound files by time. **Init sequence:** after **`session-memory.sh begin-run`** (when not **`--resume`**), run **`scripts/tools/session-memory.sh write-trace-anchors`** once — or rely on the single idempotent subcommand (preferred over manual **`write`** lines).

**Canonical line formats** (one line each; start at column 0; appended under **`## Timeline`** after that header — **append-only**, stable relative to later pipeline writes). Values are single-line; parsers should trim surrounding ASCII whitespace on the value side.

| Line prefix | Value | Meaning |
|-------------|-------|---------|
| **`SESSION_START:`** | UTC timestamp | Start of the trace window for this run. **Format:** ISO-8601 **`YYYY-MM-DDTHH:MM:SS.sssZ`** (milliseconds, **`Z`** = UTC). Example: **`SESSION_START: 2026-04-10T23:45:12.345Z`**. |
| **`PROJECT_HASH:`** | Directory name | **Exactly** the stdout of **`scripts/tools/cursor-project-hash.sh`** run with one argument: the **trace root** (single line, no newlines). Default trace root is the orchestrator **`$ROOT`**; **ROAD-48:** when **`attach-target.txt`** is present, the trace root is the **target** repo root (see paragraph below). Matches **`~/.cursor/projects/<PROJECT_HASH>/`**. Example: **`PROJECT_HASH: Users-vivian-lied-GitWorkspace-agentic-workspace`**. |

**Parsing notes for tooling:** Match lines with **`^SESSION_START:\s*`** and **`^PROJECT_HASH:\s*`**; strip one optional space after the colon if present; **`PROJECT_HASH`** must not contain whitespace after trim. **`audit-session-trace.py`** should treat **`SESSION_START`** as the lower bound for **`.jsonl`** **mtime** inclusion (see session trace audit docs).

**`cursor-project-hash.sh` encoding** (macOS/Linux; document if Cursor changes): resolve **`REPO_ROOT`** with **`pwd -P`**, strip one leading **`/`**, replace **`.`** with **`-`**, then replace **`/`** with **`-`**. **`--help`** describes the same; **`--verify`** prints whether **`$HOME/.cursor/projects/<hash>`** exists and whether **`agent-transcripts/`** is present.

**Folder vs `.code-workspace` / multi-root (PROJECT_HASH mismatch):** **`write-trace-anchors`** runs **`scripts/tools/cursor-project-hash.sh`** with one argument: the **trace root**. By default that is **`$ROOT`** (orchestrator — parent of **`scripts/tools/`**, same as **`cursor-project-hash.sh`** with no args). **ROAD-48:** when **`docs/sessions/<id>/attach-target.txt`** exists (written by **`attach-project.sh`**) with a valid directory path, **`write-trace-anchors`** and **`pipeline-init.sh`** use that **target** root instead so **`PROJECT_HASH`** aligns with the writable repo in a multi-root workspace. The hash still matches **`~/.cursor/projects/<PROJECT_HASH>/`** only when Cursor’s effective workspace identity matches that path (after **`pwd -P`**). If the user opens a **`.code-workspace`** without **`attach-target.txt`**, a **multi-root** parent folder, or a **different clone path**, Cursor may store transcripts under a **different** directory name than the computed hash. Symptom: **`audit-session-trace.py`** finds **no** matching **`.jsonl`** files. Mitigations: use **`attach-project.sh`** so **`attach-target.txt`** is set; inspect **zero-match diagnostics** in **`context-audit.log`**; compare hashes manually; or run **`cursor-project-hash.sh`** from the path Cursor shows as the workspace root.

**Run-pipeline §1 / §5 vs multi-root (ROAD-48):** For **`/run`** **§1** branch consent, the orchestrator runs **`scripts/tools/git-inspect.sh --repo <TARGET_ROOT>`** when **`attach-target.txt`** supplies **`TARGET_ROOT`** (the writable repo). Without multi-root attach, use **`git-inspect.sh`** with no **`--repo`** (orchestrator repo). For **§ 5** **`Task(dev|sre|data)`**, set the **`Task`** **`working_directory`** to **`TARGET_ROOT`** when **`attach-target.txt`** is present; pass **`WORKTREE_PATHS`** only for worktrees **inside** that repo. **§2 Init** (**`pipeline-init.sh`**) always runs from the **orchestrator** root — see **`.cursor/skills/run-pipeline/SKILL.md`** **§1** and **§2**.

**Idempotence and `--resume`:** If both **`SESSION_START:`** and **`PROJECT_HASH:`** lines already exist in **`current.md`**, **`write-trace-anchors`** is a no-op (repeat invocations safe). **`--resume`** does not rotate the session id; if anchors are **present**, **`write-trace-anchors`** no-ops. If **`--resume`** is passed and anchors are **missing** (unusual), the command **does not** write new anchors (avoids splitting the trace window); the orchestrator should treat that as a configuration gap.

**Pre-plan handoffs:** Resolve the active session directory with **`scripts/tools/session-memory.sh session-root`** (workspace-relative path to **`docs/sessions/<id>/`**, exit 1 if none). **`session-handoff.sh`** resolves the same path internally (repo root + **`session-root`**) and writes **`pre-plan/merged-brief.md`** or **`pre-plan/specialists/<name>.md`** — behavior matches **`.cursor/skills/run-pipeline/SKILL.md`** (*Handoff on-disk contract*). Write merged and specialist artifacts with **`scripts/tools/session-handoff.sh`** — e.g. **`write-handoff merged <file>`** and **`write-handoff specialist <name> <file>`** with **`name`** one of **`glean`**, **`arc`**, **`jira`**, **`confluence`**, **`gitlab`**. Content can be a file path or stdin (use **`-`** for stdin). Each file gets minimal YAML frontmatter (**`kind`**, **`written`** timestamp, and **`specialist`** for specialist files). **Orchestrator responsibility:** after each pre-plan **merge** (including the final brief passed into **`Pre-plan context:`** for **`Task(plan)`**), write **`pre-plan/merged-brief.md`**; after each specialist **`Task(mcp-*)`** completes, write the corresponding **`pre-plan/specialists/<name>.md`** with a **capped** snapshot (align with run-pipeline **Pre-plan context** — condensed briefs, not full transcripts). Shell alternative without the helper: ensure **`session-root`** exists, then **`mkdir -p …/pre-plan/specialists`** and redirect a heredoc or **`cat`** into the paths above.

**Mid-run specialist files:** Same **`pre-plan/specialists/`** tree; use **non-colliding** paths or filenames for **`REQUEST_MAIN`**-driven **`Task(mcp-*)`** (see table row **mid-run** above and skill **§ 5**). Prefer a subdirectory (**`pre-plan/specialists/mid-run/`**) or a stable suffix pattern so pre-plan **`{glean,arc,jira,confluence,gitlab}.md`** remain the wave artifacts.

**Persistence contract (waves skipped vs specialists):**

| Situation | **`merged-brief.md`** | **`pre-plan/specialists/*.md`** |
|-----------|----------------------|----------------------------------|
| Normal two-wave run | After each merge step that feeds **`Task(plan)`**; final file reflects Wave 1 + Wave 2 combined, summarized | One file **per specialist that ran** only — no empty placeholders |
| **Wave 1 skipped** (triage lists neither **`glean`** nor **`arc`**) | Still write after **merge + gate** (post-triage or empty Wave 1 merge): body should reflect that Wave 1 was omitted and what was merged for Wave 2 / final handoff | **No** **`glean.md`** / **`arc.md`** unless those **`Task(mcp-*)`** actually ran |
| **Pre-plan skipped** (**`--skip plan`**) | Usually absent — no pre-plan segment | Usually absent |

Scripts do not auto-delete stale specialist files from an earlier run; the orchestrator overwrites or creates files for the current pre-plan only.

**Retention:** **`prune`** deletes session **files** older than 24 hours by mtime (**`find … -mmin +1440`**, same rule as before). The **`ACTIVE_SESSION`** file is excluded from that sweep (**`-name` filter**). After file prune, **empty** timestamped session directories under **`docs/sessions/`** may be removed (optional cleanup); if the active id’s directory was removed, **`init`** creates a **new** session on the next run.

**`--resume`:** Does **not** run **`begin-run`**; read the active session’s **`current.md`** (resolve via **`ACTIVE_SESSION`**), find the last **`GATE:`** or **`FAILURE:`** entry, and continue from the next step — same as when the file was a single flat **`docs/sessions/current.md`**. For **which** **`GATE:`** shapes apply after plan vs implementation vs QA, and how **`GATE: impl | DONE | phase: k`** orders multi-phase **`/run`** recovery, see **`.cursor/skills/run-pipeline/SKILL.md`** (**Interaction with `--resume`**, **§ 6**).

### Local auditing

Session content under **`docs/sessions/`** is **gitignored** (local-only). To **inspect** what happened in a pipeline run:

- **List session folders:** `ls -1 docs/sessions/` (or sort by id — ids are UTC **`YYYY-MM-DDTHHMMSSZ`**). Ignore **`ACTIVE_SESSION`** when listing directories; the active id is also in **`cat docs/sessions/ACTIVE_SESSION`**.
- **Active session root:** `scripts/tools/session-memory.sh session-root` (workspace-relative path to **`docs/sessions/<id>/`**).
- **Proof pre-plan ran:** presence of **`pre-plan/merged-brief.md`** and/or **`pre-plan/specialists/*.md`** under that session root (only files for specialists actually invoked). Empty or missing **`pre-plan/`** means pre-plan did not run, was skipped (**`--skip plan`**), or the orchestrator did not write handoffs.
- **Proof codebase-explorer ran:** under **`artifacts/explorer/`**, one or more **`.md`** files after **`REQUEST_MAIN: codebase-explorer`** (and **`EXPLORATION:`** or equivalent in **`current.md`**). Absent if no exploration escalation occurred.
- **Proof QA prep (§ 7.0) ran:** after a full **`/run`** that executed **`Task(qa)`** (**`--skip qa`** absent), list **`artifacts/scanners/`** — expect **`spec-validator.md`** and **`security-scanner.md`**. Missing scanner output when QA ran implies the orchestrator skipped **§ 7.0** (invalid per skill **Invalid completion**). If **`--skip qa`**, **`artifacts/scanners/`** is not required.
- **Gate / resume evidence:** lines in **`current.md`** (under **`## Timeline`**) such as **`GATE:`**, **`FAILURE:`**, **`PIPELINE: COMPLETE`**, optional **`COMMIT_SUGGESTIONS:`** / **`PUSH_CONFIRMED:`** (Finish audit lines). For a successful Finish, **`PIPELINE: COMPLETE`** is the **last** **`session-memory.sh write`** for the run (see run-pipeline **§ 9**). **Resume** uses **`GATE: impl | DONE | …`** (and plan / final-scrum gates); **§ 5–§ 6** also emit parseable **`impl | START`**, **`impl | DONE`**, and **`impl-review | GATE | …`** for operator timelines (see the skill — not duplicated here).
- **Finish UX (orchestrated):** When **`AskQuestion`** is available, Finish uses the **tool first** for commit / push / MR prompts; chat-only Finish walls are **not** the primary path. Actual **`git`** + **`audit-session-trace.py`** run via **`scripts/hooks/pipeline-finish.sh`** per skill **§ 9**. See **`.cursor/skills/run-pipeline/SKILL.md`** **§ 9** — **Tool-first Finish** and **Finish script**.
- **Trace anchors:** **`SESSION_START:`** and **`PROJECT_HASH:`** in **`current.md`** (see **Session trace anchors** above). Written during **§2 Init** inside **`scripts/hooks/pipeline-init.sh`** (which calls **`session-memory.sh write-trace-anchors`**); they bound which local Cursor transcript files belong to this run.
- **`docs/audit.log`:** Hook/session events appended locally (not a substitute for session **`current.md`**; different purpose — security and workflow markers). **`scripts/tools/metrics.sh`** can aggregate local usage when configured; nothing is sent off-machine by default.
- **`context-audit.log`:** Under **`docs/sessions/<id>/`**, written when **`scripts/hooks/pipeline-finish.sh`** runs **`scripts/tools/audit-session-trace.py`** at **Finish** (orchestrated **`/run`**, before **`PIPELINE: COMPLETE`**). Policy is **append-only**: each Finish run adds one bounded section (UTC **Finished** timestamp), never truncating the whole file. See **`audit-session-trace.py --help`**. The orchestrator **must not** invoke **`python3 …/audit-session-trace.py`** outside **`pipeline-finish.sh`** for the normal Finish path.

**Finish audit delay (optional):** Pass **`--pre-audit-delay-seconds N`** to **`pipeline-finish.sh`** (forwarded to **`audit-session-trace.py`**) **only at Finish** if JSONL flush timing requires it. Keep **`N=0`** unless you see repeated zero-match audits; do not add sleeps elsewhere in the pipeline by default.

**Pre-flight / previous-run analysis (optional):** Git does not store historical **`ACTIVE_SESSION`** values. For debugging **hash** or **session** confusion, use **`--prior-session-hints`** to append anchors from the **newest other** **`docs/sessions/*/current.md`** (by file mtime), or manually inspect archived session folders. A **second** audit at the **start** of the **next** **`/run`** (against the prior session directory) is a documented fallback when same-run Finish transcripts stay empty — not a default Init step (skill section 2).

**Isolation:** The audit utility reads **`PROJECT_HASH`** only from the active session’s **`current.md`** and **selects** transcript files from **`$HOME/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`** using the **mtime** window. It does **not** merge other projects into the **payload** for a successful match. When **no** **`.jsonl`** qualifies (or the directory is missing), **zero-match diagnostics** include a **bounded** listing of other **`~/.cursor/projects/<hash>/agent-transcripts/`** trees (see **`audit-session-trace.py --help`** epilog for caps). **`.jsonl`** files are included in the primary sweep only when filesystem **mtime** is **on or after** **`SESSION_START`**. Concurrent **`/run`** sessions in **other** repo checkouts use different **`PROJECT_HASH`** values and do not cross-leak into the primary sweep. Validate with the **manual** procedure below (short pointer: **`docs/sessions/README.md`**).

Conventions pointer (tracked file in an otherwise gitignored tree): **`docs/sessions/README.md`**.

### Parallel stress test (manual)

**Purpose:** Prove **two-repo isolation**: overlapping orchestrated **`/run`** sessions in two different workspace roots must not cause Repo A’s **`context-audit.log`** to reference Repo B’s **`PROJECT_HASH`** or B-only transcript artifacts.

**Setup**

- Two terminals (or two Cursor windows), each workspace opened at **Repo A** and **Repo B** respectively. Use **different** clone paths so **`PROJECT_HASH`** differs (mandatory precondition).
- From each repo root, print the hash: **`scripts/tools/cursor-project-hash.sh`**. Record **`PROJECT_HASH_A`** and **`PROJECT_HASH_B`**. Assert **`PROJECT_HASH_A` ≠ `PROJECT_HASH_B`** before starting — if they match, you are not testing cross-repo isolation.

**Procedure**

1. Start overlapping non-resume **`/run`** sessions so both pipelines are active through at least one **§9 Finish** that runs **`audit-session-trace.py`** (timing overlap is what stresses isolation).
2. After Repo A finishes (or at least after A’s Finish audit), in **Repo A** resolve the session directory: **`scripts/tools/session-memory.sh session-root`** and open **`context-audit.log`** under that path.

**Assertions (Repo A only)**

- The log and anchors are consistent with **Repo A**: **`current.md`** for A’s session contains **`PROJECT_HASH:`** equal to **`PROJECT_HASH_A`**; **`context-audit.log`** must not contain the literal string **`PROJECT_HASH_B`** (nor a **`PROJECT_HASH:`** line with B’s value).
- **Transcript filenames:** If you list **`$HOME/.cursor/projects/<PROJECT_HASH_B>/agent-transcripts/*.jsonl`**, none of those **basenames** should appear in Repo A’s **`context-audit.log`** (B-only files must not be attributed to A’s sweep).

**Automation:** **Manual** only for this procedure unless a follow-up adds a scripted harness (none required here).

### Audit payload accuracy (qualitative)

Compare reported **token counts**, **truncated excerpts**, and **file hints** in **`context-audit.log`** against **spec-sized** orchestration inputs — **least privilege**, same *spirit* as **plan-segment context slicing** (bounded **`Plan segment feedback`**, condensed **`Pre-plan context:`**, no whole-transcript replay). The audit utility must not imply a whole-repo scan.

**Checklist (qualitative)**

1. **Anchors:** In **`current.md`**, **`PROJECT_HASH:`** matches **`cursor-project-hash.sh`** stdout for **this** repo root only; the Finish section in **`context-audit.log`** should align with that hash and with **`~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`** — not paths under a sibling **`~/.cursor/projects/<other-hash>/`**.
2. **Volume sanity:** Totals and excerpt sizes should look like **bounded JSONL fields** from the run window, not like every source file in the repository was ingested. If numbers are orders of magnitude beyond plausible **`Task`** / orchestrator context for the spec, treat as a red flag and verify caps in **`audit-session-trace.py`**.
3. **Path spot-check:** File paths mentioned in the log (if any) should resemble **work touched in the session** (e.g. spec paths, scripts under change) — not arbitrary bulk globs across unrelated trees.
4. **Time window:** **`SESSION_START:`** in **`current.md`** should bound **mtime** inclusion; Finish timestamps should be after the run’s trace window start.
5. **Plan-segment alignment:** Like plan-segment slicing, telemetry should reflect **narrow** inputs to **this** pipeline — not a dump of all prior chat or full-repo indexing. See **Context slicing (plan segment)** earlier in this doc.

### Manual verification (pre-plan orchestration)

Use this checklist when validating **orchestrator docs** and **live `/run`** behavior (no CI substitute for branch UX and **`Pre-plan context:`** shape). Short pointer list: **`docs/sessions/README.md`**.

- **(a) Protected branch halt** — Start **`/run`** on a **protected** branch (`main`, `master`, `develop`, `release/*`). Expect a **hard stop** at **§1** until the user chooses abort, switch, or an **approved** new branch name — **no** Init, pre-plan **`Task(mcp-*)`**, or **`Task(plan)`** before that consent (see skill **§1 Ordering (gate)**).
- **(b) Jira-only / Wave 2-only (no Wave 1)** — Use a goal where **`Task(pre-plan-triage)`** lists **no** Wave 1 sources (**neither** **`glean`** nor **`arc`**) but **may** need **`jira`** / **`confluence`** / **`gitlab`**. Expect **no** **`Task(mcp-glean)`** or **`Task(mcp-arc)`** — **merge + gate** after triage (or an empty Wave 1 merge), then Wave 2 only as gated.
- **(c) `Pre-plan context:` vs raw MCP JSON** — After pre-plan, inspect the **`Task(plan)`** prompt or orchestrator log: **`Pre-plan context:`** must be a **short, summarized** brief (bullets / pointers), **not** a paste of full MCP tool JSON or unbounded dumps. On disk, **`pre-plan/merged-brief.md`** is the **bounded** merged artifact; **`pre-plan/specialists/*.md`** are **capped** snapshots — see **Local auditing** above and **Persistence contract** in **Session storage**.

### Manual verification (plan segment)

Use this checklist when validating the **plan segment** (between optional pre-plan and **§ 5** implementation). Authoritative procedure remains **`.cursor/skills/run-pipeline/SKILL.md`** (**§ 3–4**, **Manual step gates**).

| Test / theme | What to verify (manual / live `/run`) |
|----------------------|----------------------------------------|
| **Test Anti-Nesting** | Use a **`/run`** goal that targets an **unfamiliar or un-indexed** directory so **`Task(plan)`** cannot orient from KB/ARC alone. Expect **`REQUEST_MAIN:`** (or **`QUESTION:`**) in **`Task(plan)`** output — **not** a nested **`Task(codebase-explorer)`**. The **orchestrator** (main session) should then run **`Task(codebase-explorer)`**, write a **bounded** markdown file under **`docs/sessions/<session-id>/artifacts/explorer/`**, append a **`session-memory.sh`** trace line (e.g. **`EXPLORATION:`** path + one-line reason), and **re-invoke** **`Task(plan)`** with the **artifact path** and/or a **capped excerpt** — **not** merging an **unbounded** scout summary into the **next** **`Task(plan)`** prompt alone. |
| **Test Context Slicing** | Force **`Task(plan-reviewer)`** below threshold on **attempt 1** (e.g. reject draft). Inspect the **attempt 2** **`Task(plan)`** prompt: it must carry **`Plan segment feedback:`** / sliced content derived from **`PLAN_REVIEW_FEEDBACK:`** (see **`current.md`**) — **without** replaying the full loop-1 **`Task(plan)`** transcript or redundant raw pre-plan dumps. |
| **Test the Loop Cap** | Document or simulate **plan-reviewer** staying below threshold through **three** inner-loop iterations. Expect **no** automatic fourth plan-review iteration; orchestrator uses **`AskQuestion`** (or chat fallback: Proceed anyway / Abort / Provide guidance) and an **`ESCALATION:`** line in **`docs/sessions/<id>/current.md`** for plan-segment max iterations (see skill). Matches **`--max-plan-iterations`** (default **3**). |
| **Test Scrum Authority** | Under **`[DELEGATION MODE: orchestrated]`**, **`Task(plan)`** returns **Proposed spec updates** only; **`status`**, **`[x]`**, and **`last-updated`** stay unchanged until **`Task(do)`** applies them **after** **`Task(scrum)`** **PROCEED**. Manual proof: **`git diff`** / mtime on **`docs/specs/...`** — no spec mutation before that gate. |
| **`--manual` pause (workflow step 7)** | Run **`/run --manual`**. After **plan + plan-review + `Task(scrum)`** for the plan segment returns **PROCEED**, expect a **manual step gate** (**AskQuestion** or numbered chat: Proceed / Force review / Add context) **before** **§ 5** **`Task(dev|sre|data)`**. See **Manual step gates (`--manual`)** above and the skill **Manual step gates** section. |

**Optional CI helper:** **`scripts/tools/check-plan-segment-docs.sh`** (warnings-only, always exit **0**) greps the skill (and related files) for **`PLAN_REVIEW_FEEDBACK`**, **`--max-plan-iterations`**, and the **`REQUEST_MAIN:`** escalation chain — same non-blocking pattern as **`check-nested-task-docs.sh`** in the **`docs-check`** job.

### QA and Git boundaries manual acceptance (human)

Use this matrix when **proving** **§ 7–9** boundaries in a **live** **`/run`** session. **Automated** enforcement is **`scripts/tools/verify-qa-git-boundaries.sh`** (blocking; **`docs-check`** in **`.gitlab-ci.yml`**) — it **grep-checks** normative text in **`.cursor/skills/run-pipeline/SKILL.md`**, **`.cursor/agents/qa.md`**, **`.cursor/agents/summary.md`**, and **`.cursor/rules/git-gitlab-mutations.mdc`**. It does **not** replace observing orchestrator behavior, **`git`** history, or Finish prompts.

| Theme | What to verify (manual / live `/run`) | Automation vs manual |
|-------|----------------------------------------|----------------------|
| **QA anti-nesting** | Through **`Task(qa)`**, confirm the **orchestrator** does **not** chain **`Task(spec-validator)`** or **`Task(security-scanner)`** as **nested** delegations **from** **`Task(qa)`**. The QA persona may use **shell scripts** and **session-local** tooling (e.g. **`scripts/tools/run-tests.sh`**, **`scripts/tools/lint-check.sh`**, **`scripts/tools/git-diff-summary.sh`**) — that is **not** the same as the main session scheduling nested **`Task(...)`** specialists inside QA. | **Automated:** **`verify-qa-git-boundaries.sh`**. **Manual:** inspect **`/run`** logs / **`Task`** structure for the forbidden nested pattern. |
| **Scrum authority (spec untouched during QA)** | After **`Task(qa)`** returns **Proposed spec updates**, the spec file must stay **unchanged** on disk until **§ 7.1** **`Task(scrum)`** **PROCEED** authorizes **`Task(do)`** to apply them (no **`status`**, **`[x]`**, or **`last-updated`** from QA applied early). | **Automated:** verifier asserts SKILL wording on withholding QA proposals until **§ 7.1**. **Manual:** **`git diff docs/specs/...`** / mtime — no spec mutation between QA return and **§ 7.1** **PROCEED**. |
| **Git boundaries (no commit / commit + no push)** | In **§ 9 Finish**: if the user chooses **Do not commit** (or **other / manual** without committing), expect **no** **`git commit`**. If the user picks an **orchestrator-offered** message, **`git add -A`** / **`git commit`** may run **only** for that choice. If **Push** is answered **No**, expect **no** **`git push`**; **`git push`** only after an explicit **Yes** to the Finish Push prompt (see **`.cursor/rules/git-gitlab-mutations.mdc`**). | **Automated:** verifier checks **git-gitlab-mutations** + SKILL **§ 9** phrasing. **Manual:** exercise Finish options and confirm **`git log`** / remote state matches choices. |
| **MR safety (instructions only)** | When Finish offers MR guidance, expect **instructions** and **read-only** MR body text (e.g. stdout from **`scripts/tools/mr-description-from-spec.sh`**) for the **user** to paste or run — **never** **`glab mr create`**, mutating GitLab API calls, or autonomous MR create from the orchestrator. See **`docs/reference/gitlab-cursor-workflow.md`**. | **Automated:** **`verify-qa-git-boundaries.sh`** greps SKILL for **§ 9** MR safety strings. **Manual:** confirm only **Shell**-surfaced commands / script output — **no** write APIs. |
| **§ 8 Summary (orchestrator prompt)** | The main session must pass a **minimal delegation bundle** to **`Task(summary)`** (QA excerpt, **§ 7.1** scrum outcome, spec path/status) — **not** full phase chat logs or whole raw **`git diff`** blobs. The summary persona may still run **`scripts/tools/git-diff-summary.sh`** and scoped reads **inside** its session. | **Automated:** verifier greps **`.cursor/agents/summary.md`**; normative text in **`SKILL.md`** **§ 8**. **Manual:** inspect what the orchestrator attaches to **`Task(summary)`** in a live **`/run`**. |

Pre-MR local check: **`./scripts/tools/verify-qa-git-boundaries.sh`** (same as **CONTRIBUTING.md** when touching listed files).

## Delegation chain

Order matches **`.cursor/skills/run-pipeline/SKILL.md`** (**§1** Preconditions → **§2** Init → optional pre-plan → Plan segment → …). **§1** must finish (branch consent on protected branches resolved or run aborted) **before** **§2 Init**, **Pre-plan context**, or **`Task(plan)`**.

```
User → Main session agent (reads run-pipeline skill)
     → §1: branch / worktree preconditions (git-inspect.sh; protected branch → user consent before anything below)
     → §2 Init (pipeline-init.sh: begin-run if not --resume; write-trace-anchors; apply-models snapshot; session-memory read; optional knowledge-source note)
     → [optional] Task(pre-plan-triage)
     → Wave 1: parallel Task(mcp-glean) + Task(mcp-arc) (each only if triage lists it; omit whole wave if neither) → merge
     → Gate → Wave 2: Task(mcp-jira) | Task(mcp-confluence) | Task(mcp-gitlab) (each only if triage or merged brief needs it) → final merge (summarized; merged-brief.md on disk)
     → Task(plan) (condensed **Pre-plan context:**) ↔ Task(plan-reviewer) self-heal (max iterations) → Task(scrum) plan gate
     → Task(dev|sre|data) per phase ↔ *-reviewer + Task(scrum) per § 6
     → § 7.0: parallel Task(spec-validator) + Task(security-scanner) → artifacts/scanners/ → Task(qa)
     → Task(scrum) § 7.1 → Task(summary) → Finish (pipeline-finish.sh: commit/push + audit …)
```

Only the **main session** schedules **`Task(...)`**; personas do **not** nest **`Task`** calls (see skill **Delegation header** item 7). For **`/run`** pre-plan MCP gather, **`/plan` must not** nest **`Task(mcp-*)`** — orchestrator-flat **only** (see **Pre-plan MCP gather** — **Nested vs flat**).

On **full `/run`** (when Plan is not skipped), the orchestrator may run **Pre-plan context (optional MCP)** **after** **§2 Init** and **before** **`Task(plan)`** — see **Pre-plan MCP gather** below. **`--skip plan`** skips both pre-plan and **`Task(plan)`**.

### Task `description` convention (parallel distinguishability)

When the Cursor product supports it, pass a **`description`** on **`Task(...)`** (or put the same text as the **first line of the prompt**) so parallel runs are identifiable in logs — e.g. **`Dev (Phase 2 — my-spec-slug)`**, **`Task(mcp-arc)`** as **`MCP ARC (pre-plan — my-spec-slug)`**. Match **`.cursor/skills/run-pipeline/SKILL.md`** § 5 / Pre-plan steps. If **`description`** is unavailable, use the prompt’s first line as the display name.

Persona subagents do the work. The main agent coordinates, parses results, and advances gates — it must **not** substitute for `/plan` or `/dev` on substantive work.

## Parallelism

- **Pre-plan (two-wave):** **Wave 1** — parallel **`Task(mcp-glean)`** and **`Task(mcp-arc)`** **only** when triage lists them (omit the whole wave if neither applies). **Merge + gate.** **Wave 2** — **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, **`Task(mcp-gitlab)`** **only** when triage **or** the merged Wave 1 brief indicates need (issue keys, Confluence space, MR/project refs). **Final merge** → **`Task(plan)`**. See **Pre-plan MCP gather** and **`.cursor/skills/run-pipeline/SKILL.md`**.
- **Phased specs (`### Phase 1:` …):** **At most one** spec phase per **`Task(dev|sre|data)`** — do not delegate a single implementation **`Task`** that covers multiple phases. After phase *k*’s implementation **`Task`**(s) finish, run **implementation review + `/scrum`** for that phase (default batched reviewers + scrum vs **`--manual`** per-track rules in the skill) **before** phase *k+1* implementation. If every phase is the same domain (e.g. all `[dev]`), use **separate** **`Task(dev)` per phase** anyway.
- **Implementation:** Within **one** phase, `/dev` + `/sre` + `/data` may launch in parallel using `run_in_background: true` + `Await` (see skill). **Exception — `--manual`:** domain tracks run **sequentially** (dev → sre → data per spec) **within that phase**; no parallel impl in that mode.
- **Review:** Domain reviewers in parallel **for that phase**, then `/scrum` with collected scores **for that phase**. **Exception — `--manual`:** per-track reviewer + scrum after each track **within the phase** (see skill).
- **QA:** Orchestrated **`/run`** runs **§ 7.0** — parallel **`Task(spec-validator)`** + **`Task(security-scanner)`** **before** **`Task(qa)`**, with **`artifacts/scanners/`** on disk (**`.cursor/skills/run-pipeline/SKILL.md`**). Readonly validation **inside** **`Task(qa)`** may **additionally** use **session-local** workflows (**scripts**, merged outputs) — **not** **`Task(spec-validator)`** / **`Task(security-scanner)`** **nested from** **`Task(qa)`**. Same idea as **QA and Git boundaries manual acceptance** above and the skill (**Parallelism** → QA, **Agent roster**).
- **Parallelism / Nested delegation:** Top-level parallel **`Task`** calls (same message) differ from **nested** **`Task`** (subagent invoking **`Task`** again). Nested chains can be unreliable unless the **session** uses a **capable model tier** — team guidance: **max** (or org equivalent) for **`/run`** when personas chain delegations. See **`docs/reference/cursor-agents.md`** (**Nested `Task` / subagent reliability**). Orchestration shape (**Delegation chain**, above) and per-agent model IDs (**Model Plan & apply-models.sh**, below) work together: YAML assigns IDs; session tier still caps nested behavior.

### Pre-plan MCP gather

**Order (mirrors `.cursor/skills/run-pipeline/SKILL.md` — headings *Pre-plan context (optional MCP)* and *Plan (`Task(plan)`)*):**

1. **`Task(pre-plan-triage)`** — Structured output: **`wave1_sources`** (**`glean`**, **`arc`**), **`follow_up`** / **`wave2_sources`** (**`jira`**, **`confluence`**, **`gitlab`**), **`jira_keys`**, **`confluence_space`**, **`gitlab_refs`**, **`gate_hints`**, query hints, caps — see **`.cursor/agents/pre-plan-triage.md`**.
2. **Wave 1 —** In parallel (`run_in_background` + **`Await`**), run **`Task(mcp-glean)`** and/or **`Task(mcp-arc)`** **only** for sources triage lists for wave 1. **Skip Wave 1** if triage lists neither (e.g. **only** Jira or GitLab follow-up). After each specialist **`Task`** returns, write **`pre-plan/specialists/{glean,arc}.md`** (see **Session storage**).
3. **Merge + gate** — Merge Wave 1 into a working brief. Decide whether to run Wave 2 from triage fields **and/or** the merged Wave 1 text (e.g. surfaced Jira keys, “see Confluence”, MR link).
4. **Wave 2 —** In parallel when multiple apply, run **`Task(mcp-jira)`**, **`Task(mcp-confluence)`**, **`Task(mcp-gitlab)`** **only** as needed. Write **`pre-plan/specialists/{jira,confluence,gitlab}.md`** for each that ran.
5. **Final merge** — One **summarized** merged external brief for **`Task(plan)`** (bounded text — align with on-disk **`merged-brief.md`**). Persist **`pre-plan/merged-brief.md`** (**`session-memory.sh session-root`**).
6. **`Task(plan)`** — Prompt includes **`Pre-plan context:`** with that **condensed** brief (plus user goal) — **not** raw specialist JSON dumps. **Local auditing:** proof lives under **`pre-plan/`** (see **Session storage** — **Local auditing**). Manual checks: **Manual verification (pre-plan orchestration)** above.

**Nested vs flat:** **Orchestrator-flat** MCP gather means **only the main session** runs triage + **`Task(mcp-*)`** for this step. **`/plan` must not** nest **`Task(mcp-*)`** for gather when executing under **`/run`** — that pattern is **nested** and discouraged for reliability. Same specialists may be **re-invoked later** from the main session (e.g. after a reviewer asks for more Jira context); merge and attach to the **next** downstream **`Task`**, still **not** as chains inside **`/plan`** / **`/dev`**. See **Parallelism / Nested delegation** above and **`docs/reference/cursor-agents.md`**.

## Manual step gates (`--manual`)

Optional **`/run --manual`** enables **manual step gates** (orchestration pauses after the plan segment and after each domain track), not **manual model assignment** from `.cursor/models.user.yml`. Optional **MCP** (GitLab, Atlassian, Glean) does not change these gates — tools remain **optional** per **`00-workspace-router.mdc`**. Authoritative behavior: **`.cursor/skills/run-pipeline/SKILL.md`** section **Manual step gates (`--manual`)**.

| Topic | Behavior |
|--------|----------|
| **Pause points** | After **plan + plan-review + scrum** (gate 1); after each **domain track** (impl + `*-reviewer` + scrum for that segment) before the next track or QA. |
| **Default `/run`** | Parallel implementation when the spec allows; batched impl-review + scrum. |
| **`--manual`** | **Sequential** domain tracks; each track: `Task(domain)` → `Task(*-reviewer)` → `Task(scrum)` → **AskQuestion** (or numbered chat): **Proceed** / **Force review** / **Add context and review** (session-memory + re-run reviewer then scrum per skill). |
| **`--review`** | **Orthogonal** — optional per-step checkpoints; does not replace `--manual` gates. |
| **`--resume`** | If paused **at** a manual gate, resume **re-offers** that gate; else continue after last `GATE:` / `FAILURE:` (see skill). |

### Disambiguation: manual **models** vs `--manual` step gates

| | Manual **models** (`use_manual_models`) | **`--manual`** (step gates) |
|---|---------------------------|----------------------------|
| **What** | `use_manual_models: true` in `.cursor/models.user.yml`; fixed model IDs; no per-step `apply-models.sh` overrides | Orchestration pauses after plan segment and after each domain track |
| **Config / flag** | YAML + `apply-models.sh --show-source` | `/run --manual` |
| **See also** | **Model Plan & apply-models.sh** (above), **Dynamic Model Selection** (below) | **run-pipeline** skill **Manual step gates** |

Set orchestration state **`manual_step_gates: true`** when the user passes **`--manual`** (see **Pipeline State Variables**).

## Anti-patterns (orchestrating agent must NOT)

- Implement application code, specs, or full reviews **in place of** `Task(plan)`, `Task(dev)`, etc.
- Create a git branch **without** explicit user approval of the name.
- Emit **`PIPELINE: COMPLETE`** after skipping required steps (unless matching **`--skip`** flags).
- Pre-read large specs or codebases to “prepare” before `Task(plan)` — pass the user goal and let `/plan` discover.
- Re-derive information already returned by a subagent — use the Task result.
- Send **one** **`Task(dev|sre|data)`** that implements **multiple** spec **`### Phase N:`** sections, or **start** the next phase’s implementation **before** implementation review + scrum **for the current phase** complete (see **Parallelism** — phased specs).

## Working Repo Architecture

The agentic-workspace is a FRAMEWORK repo. App projects (myapp/, avatax-db-script/, etc.) are independent git repos cloned inside the workspace root and gitignored. They exist on disk but are NOT part of the workspace git history. The pipeline reads framework files from the workspace and makes code changes in the working repos. Worktrees are created in the working repos for isolation.

## Delegation Header

Include this header on **every** Task prompt to a delegated persona (authoritative wording is in **`.cursor/skills/run-pipeline/SKILL.md`**):

```
[DELEGATION MODE: orchestrated]
This task is delegated by the run-pipeline skill (main agent). Behavioral overrides:
1. SKIP routine user confirmation — save outputs directly unless APPROVAL_NEEDED.
2. If you need clarification, prefix with QUESTION:.
3. If blocked on approval, prefix with APPROVAL_NEEDED:.
4. Return structured result: spec path, scores, files touched, blockers.
5. OVERRIDE for mutating git / GitLab: persona agents never run `git commit`, `git push`, or MR creates. The orchestrator invokes **`scripts/hooks/pipeline-finish.sh`** only per **run-pipeline § 9 Finish** (after **`AskQuestion`** / chat: **`--commit-message`** when the user selects an offered message, **`--no-commit`** otherwise; **`--push true`** only after explicit **Yes** to the Finish **Push** prompt); MR and mutating GitLab API remain user-run.
6. Spec progress: do not flip task checkboxes `[x]`, `status`, or `last-updated` in the spec — return **Proposed spec updates** for the orchestrator after **`Task(scrum)`** PROCEED (or explicit user override). See **Per-phase gates (mandatory)** above.
```

## Finish: commit, push, MR

- **Commit / push / audit:** The main session runs **`scripts/hooks/pipeline-finish.sh`** with **`--commit-message`** / **`--commit-file`** / **`--no-commit`** and **`--push true|false`** after **`AskQuestion`** or chat fallback — **not** raw **`git`** lines. The script performs **`git add -A`**, **`git commit`**, **`git push`** as applicable, then **`audit-session-trace.py`**. Options **do not commit** and **other / manual** map to **`--no-commit`**. See **`.cursor/skills/run-pipeline/SKILL.md`** **§ 9** and **Orchestrator shell wrappers** above.
- **Push:** **`--push true`** only after an explicit **Yes** to the Finish **Push** prompt. **Never** auto-push outside **`pipeline-finish.sh`**. See **`.cursor/rules/git-gitlab-mutations.mdc`**.
- **MR:** MR create/update and mutating GitLab API — **user-run**; orchestrator surfaces commands/body text only (same as skill **§ 9**).

## Branch naming and `--branch`

- **`--branch [name]`** is an optional **hint** for the branch name suggestion during **branch consent**; the user must still **approve** the name before creation (see skill).
- When a **spec slug** is known, prefer suggesting **`feature/{spec-slug}`** for feature work and **`hotfix/{spec-slug}`** for hotfixes. Derive **`{spec-slug}`** from `docs/specs/YYYY-MM-DD-{slug}-spec.md` (the `{slug}` portion) or the spec title slug.

## MR labels from spec domain tags

Spec task tags **`[dev]`**, **`[sre]`**, **`[data]`** (with optional `:repo`) map to GitLab labels **`dev`**, **`sre`**, **`data`** for MRs when your project uses those label names. **`scripts/tools/mr-description-from-spec.sh`** lists detected tags in its output; **`docs/reference/gitlab-cursor-workflow.md`** has `glab` examples with **user-supplied** token/branch — no secrets in-repo.

## Pipeline State Variables

`mode`, `confidence_threshold` (default 75), `qa_iteration` (0), `max_qa_iterations` (flag or 3), `max_review_loops` (flag or 2), `current_step`, `skipped_steps`, `scores = {}`, `model_strategy` (flag or `balanced`), `budget` (flag or none), `cost_estimate = 0`, `escalations = []`, `model_plan = {}`, `models_used = []`, `snapshot_path` (default `docs/sessions/.model-snapshot`, overridable via `APPLY_MODELS_SNAPSHOT`), **`manual_step_gates`** (`true` when `/run` includes **`--manual`** — orchestration pauses; **not** manual model mode).

## Model Plan & apply-models.sh Choreography

### Three modes (mental model)

| Mode | Config | Bulk apply reads | `/run` dynamic selection |
|------|--------|------------------|----------------|
| **Manual file** | `use_manual_models: true` in `.cursor/models.user.yml` | `.cursor/models.user.yml` only | **No** per-step `apply-models.sh` or `--restore-agent` |
| **Team YAML** | `use_manual_models: false` (default) | `.cursor/models.yml` | **Yes** — model plan + escalation use `apply-models.sh` + snapshot restore |
| **Dynamic pipeline** | Same as team row; orchestrator applies strategy + escalation | Baseline from team file; overrides per step | **Yes** |

Detection: `./scripts/tools/apply-models.sh --show-source` prints whether bulk would use **manual** or **team**. Parsing of `use_manual_models` is **fail-closed** to team mode if `.cursor/models.user.yml` is missing or the flag is unreadable.

**Subscription / Auto:** Use **manual mode** when you need every agent on **`default`**, **`inherit`**, or session Auto without the pipeline overwriting models each step. Edit `.cursor/models.user.yml`, set `use_manual_models: true`, run bulk apply, then run `/run`.

### Baseline snapshot

**Team (dynamic) mode:** Run `scripts/tools/apply-models.sh --snapshot "$snapshot_path"` **before** any per-agent override. After each delegated step, restore that agent: `apply-models.sh --restore-agent <agent> "$snapshot_path"` (or `--restore "$snapshot_path"` once at pipeline end). Distinct snapshot paths avoid collisions for concurrent pipelines.

**Manual mode:** Still **may** snapshot at init to record state; **do not** apply per-step overrides or `--restore-agent` (there is nothing to roll back between steps). End-of-run `--restore` only matters if something else changed frontmatter during the session; otherwise it matches the snapshot taken at init.

### Seeding the model plan

**Manual mode:** Document that models are fixed by `.cursor/models.user.yml` (no dynamic seed from team YAML). Skip catalog-driven per-step picks.

**Team + dynamic:** **Before `/plan` completes:** seed `model_plan` from `.cursor/models.yml` + `--model-strategy`. Do **not** read `docs/model-catalog.md` yet.

**After `/plan` returns:** refine `model_plan` using domain tags / risk from `/plan`'s result or one Read of the active spec. Then apply `--model-strategy` guardrails:

- `conservative` — cap at economy/standard tier; avoid `max` tier unless spec demands it.
- `balanced` — economy for lightweight reviewers/orchestrators; standard for routine impl; premium only when complexity/risk warrants.
- `quality` — floor at standard; premium for planning, QA, security-heavy steps.

Persist: `session-memory.sh write "MODEL_PLAN: {compact JSON or table}"`.

### --resume recovery

Read the active session file **`docs/sessions/<session-id>/current.md`** (session id from **`docs/sessions/ACTIVE_SESSION`**), find the last **`GATE:`** or **`FAILURE:`** entry, resume from the next step. Previously completed gates are not re-run. **Manual gates (`--manual`):** if the run stopped **at** a manual gate (user had not answered), **`--resume`** **re-offers** that gate per the skill. If the session file is missing or corrupt, start fresh and warn. Re-snapshot or reload `model_plan` / `models_used` from session memory if recorded there.

## Model Escalation Logic

When a reviewer returns a score below threshold, consider **adaptive escalation before rework**. Consult `docs/model-catalog.md` only for targeted ID picks.

### Escalation Rules

1. **Eligibility:** Has this step already been escalated? Under `quality` strategy at premium+, escalation may be unnecessary — go to rework/ASK_USER unless a specialty model helps.
2. **Adaptive target:** Infer the weak factor from the reviewer report; pick a model ID suited to that gap (security findings → premium reasoning; shallow spec critique → stronger arch model; infra gaps → SRE-class ID). Generic reports → one-tier-higher ladder.
3. **Apply:** `apply-models.sh <agent> <new-id>`, re-run the step once. Log: `session-memory.sh write "MODEL_ESCALATION: {step} | {from} → {to} | reason | score {N}%"`. **Not used in manual mode** — escalation goes to rework / ASK_USER without changing frontmatter.
4. **Not eligible:** Proceed with rework/ASK_USER.
5. **Cap:** One escalation per step. Does **not** count against `max_review_loops` or `max_qa_iterations`.
6. **Strategy effect:**
   - `conservative`: Escalate only when score < threshold + 10%; avoid max tier.
   - `balanced`: Escalate when score < threshold; adaptive target selection.
   - `quality`: Pick alternate premium/specialty IDs for weak factors.

## Cost Tracking

Maintain a running estimate using approximate token counts per agent type:

| Agent Type | Est. Input Tokens | Est. Output Tokens |
|---|---|---|
| Planning (`/plan`) | 50K | 15K |
| Implementation (`/dev`, `/sre`, `/data`) | 80K | 30K |
| Review (reviewers) | 40K | 10K |
| QA (`/qa`) | 60K | 15K |
| Summary (`/summary`) | 30K | 10K |
| Scrum (`/scrum`) | 20K | 5K |

Multiply by the model's per-token rate. Accumulate across steps.

If `--budget` is set and estimate exceeds it: `⚠ Budget warning: estimated cost ${est} exceeds --budget ${budget}`. Log to session memory; do not block.

**Usage event logging (if tooling exists):** After each Task returns, optionally Shell-invoke `scripts/tools/usage-event-append.sh` if the script exists. Do **not** implement cost-tracking tooling — that is `/dev` work.

## Model Efficiency Summary

Emit alongside the completion output:

- **Models used:** `{ step, agent, model_id }` from `models_used` and escalations.
- **Estimated cost:** rolling estimate from tiers.
- **Escalations:** count; for each, `from → to`, reason, score before retry.
- **Calibration hint:** If a model pair repeatedly underperformed (from session notes), prefer a different ID next run.

## Error Handling

- **Subagent failure:** Stop. `session-memory.sh write "FAILURE: {step} | {error}"`. Return stderr/stdout, failed step, last successful step. Suggest **`/fix`**, **`/do`**, **`/run --resume`**, or re-run **`/run`** (same escape hatch list as **`00-workspace-router.mdc`** and **`.cursor/skills/run-pipeline/SKILL.md`** **Error handling**).
- **Implementation reviewer / scrum failure (§ 6):** **Stop** — do **not** “fail-open” past **§ 6** (implementation review before **§ 7 QA** or **Finish**). Record **`FAILURE:`** or **`REWORK:`** in session memory; suggest **`/fix`**, **`/do`**, **`/run --resume`**, or re-run **`/run`**. Only **`--skip impl-review`** (explicit user opt-in) may skip **§ 6**; if you skip without that flag, **`PIPELINE: COMPLETE`** is **invalid** (same as **`.cursor/skills/run-pipeline/SKILL.md`** **Invalid completion**). **QA** (**§ 7**) has its own persona — do not confuse with implementation **§ 6**.
- **Spec corruption:** Stop; do not guess task lists.
- **Context pressure:** Compact delegation results; re-read only spec slices between steps.

### Self-heal (orchestrated runs)

**`/fix`** (bugs), **`/do`** (ad-hoc mechanical work), **`/run --resume`** (continue after logged gate/failure), or re-run **`/run`** — aligned with the skill; optional MCP availability does not change this list.

## Dynamic model selection vs manual model mode

- **Script:** `apply-models.sh` — bulk sync from **team** `.cursor/models.yml` or **manual** `.cursor/models.user.yml` depending on `use_manual_models`; single-agent `<agent> <model-id>` (refused in manual mode unless `--force`); `--snapshot` / `--restore` / `--restore-agent`; `--dry-run`; `--show-source` (manual vs team). Unknown IDs warn against `docs/model-catalog.md` but still apply.
- **Catalog:** `docs/model-catalog.md` — tier and ID reference for escalation picks when **not** in manual mode (not a cold-start read).
