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

**Context slicing (plan segment):** On each plan-review miss (until acceptance or cap), the orchestrator **persists** **`PLAN_REVIEW_FEEDBACK:`** to **`<ticket-folder>/_run/timeline.md`** via **`session-memory.sh --ticket <ticket-folder> write`**, then re-invokes **`Task(plan)`** with a **`Plan segment feedback:`** block derived **only** from that line **plus** **`Task(plan-reviewer)`** findings — **not** from replaying the full prior **`Task(plan)`** transcript, prior-turn chat history, or redundant **raw** pre-plan specialist logs. **`Pre-plan context:`** on amendment attempts stays **condensed** (same class as **`pre-plan/merged-brief.md`**). Optionally prefix with **one line** of metadata (attempt number, spec path, prior reviewer score) when it disambiguates the loop; scores **never** replace the sliced feedback block.

**`REQUEST_MAIN:` and explorer:** If **`Task(plan)`** returns **`REQUEST_MAIN: codebase-explorer <target-dir>`**, **only** the main session schedules **`Task(codebase-explorer)`**, **writes** a **bounded** Markdown report under **`<ticket-folder>/_run/explorer/`** (canonical; unique filename when multiple scouts occur in one run). **`session-memory.sh --ticket <ticket-folder> write`** trace (e.g. **`EXPLORATION:`**), then re-invoke **`Task(plan)`** with the **on-disk path** and optional **short excerpt** per **Minimal context chain** — **`/plan` must not** nest **`Task(codebase-explorer)`**. Same persist-and-re-feed pattern applies when **`Task(fix)`** returns the same **`REQUEST_MAIN`** (re-invoke **`Task(fix)`**). Authoritative procedure: **`.cursor/skills/run-pipeline/SKILL.md`** — **§ 3** **Exploration escalation**, **Least-privilege matrix**, **§ 5** **Mid-run enterprise context** ( **`codebase-explorer`** is **not** **`Task(mcp-*)`** ). See **`.cursor/agents/plan.md`** and the skill **Anti‑patterns**.

**Loop cap:** When inner-loop attempts reach **`--max-plan-iterations`** and the draft still fails plan-review thresholds, **do not** start another automatic iteration — use **`AskQuestion`** (or the same three-way chat fallback as elsewhere: Proceed anyway / Abort / Provide guidance) and record **`ESCALATION: plan-segment | max iterations`** in **`timeline.md`**.

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

## Run storage

Run scratch lives in the ticket folder, under **`<ticket-folder>/_run/`** (tracked with the ticket). Pre-plan documents live beside that directory, at **`<ticket-folder>/pre-plan/`**. The ticket folder is the run identity. `/fix` and `/do` do not write either tree. Layout:

| Path | Purpose |
|------|---------|
| **`<ticket-folder>/_run/timeline.md`** | Scratch file: **`## Timeline`** holds pipeline writes in **append order** (DECISION / QUESTION / **`GATE:`** bullets, **`impl | START`** / **`impl | DONE`**, **`impl-review | GATE | …`**, trace anchors, Finish lines). |
| **`<ticket-folder>/pre-plan/merged-brief.md`** | **Merged external brief** after pre-plan merge steps (bounded text — not raw unlimited tool dumps). Written by the orchestrator when pre-plan runs. |
| **`<ticket-folder>/pre-plan/specialists/{glean,arc,jira,confluence,gitlab}.md`** | **Per-specialist snapshot** for each **`Task(mcp-*)`** that actually ran in that **pre-plan** wave. Omit files for specialists that were not invoked. |
| **`<ticket-folder>/pre-plan/specialists/`** (mid-run) | Same directory as pre-plan handoffs. Mid-run **`Task(mcp-*)`** results use distinct filenames so they do not overwrite the wave files. **`REQUEST_MAIN: codebase-explorer`** persists under **`_run/explorer/`**. |
| **`<ticket-folder>/pre-plan/review.md`** | Latest pre-plan reviewer report. The orchestrator writes it with **`session-handoff.sh write-handoff review`** after **`Task(pre-plan-reviewer)`**. |
| **`<ticket-folder>/pre-plan/gate.md`** | Latest scrum pre-plan decision. The orchestrator writes it with **`session-handoff.sh write-handoff gate`** after **`Task(scrum)`**. The timeline still gets a **`GATE: pre-plan`** line for **`--resume`**. |
| **`<ticket-folder>/_run/explorer/`** | Directory scout output after **`REQUEST_MAIN: codebase-explorer`**. Trace line in **`timeline.md`** (for example **`EXPLORATION:`**). |
| **`<ticket-folder>/_run/scanners/`** | QA prep (§ 7.0) and per-phase security reports. Filenames: **`spec-validator.md`**, **`security-scanner.md`**, **`phase-<N>-security.md`**. |
| **`<ticket-folder>/_run/diffs/{dev,sre,data,plan}/`** | Domain diffs for reviewers. |
| **`<ticket-folder>/_run/audit.log`** | Append-only Finish audit from **`audit-session-trace.py --ticket`**. |
| **`<ticket-folder>/_run/attach-target.txt`** | Optional absolute path of the writable target clone. |
| **`<ticket-folder>/_run/session.code-workspace`** | Optional multi-root workspace file from **`attach-project.sh --ticket`**. |

**Identity:** the ticket folder is the run. **`pipeline-init.sh --ticket <folder>`** calls **`session-memory.sh ensure`**, which creates `_run/` if it is missing. **`--resume`** keeps the same timeline and does not mint new trace anchors when they are already present. The session-init hook does not allocate a run directory.

### Orchestrator shell wrappers (API / stdout contracts)

Normative paths (workspace root). The **skill** forbids chained Shell, inline **`python3 -c`**, and raw **`git`** for probes — use these scripts (**`.cursor/skills/run-pipeline/SKILL.md`** — **Non‑negotiables** item **10**).

| Script | Role | Stdout contract |
|--------|------|-----------------|
| **`scripts/hooks/pipeline-init.sh`** | **§2 Init** | **Section headers** on stdout: **`=== pipeline-init ===`**, **`=== flags ===`**, **`=== run-dir ===`**, **`=== trace-anchors ===`** (then **`write-trace-anchors: ok`**, **`trace-hash-root:`**), **`=== model-mode ===`**, **`=== apply-models-snapshot ===`**, **`=== session-memory-read ===`**, **`=== knowledge-sources ===`**, **`=== pipeline-init-status ===`** / **`ok`**. Exit **non-zero** on hard failures (**`ensure`**, **`write-trace-anchors`**, **`apply-models --snapshot`**, optional **`KNOWLEDGE_SOURCES` write**). Flags: required **`--ticket`**, optional **`--resume`**, **`--targets <dir> ...`**. |
| **`scripts/tools/git-inspect.sh`** | **§1** read-only | **Section headers:** **`=== git-inspect ===`**, **`=== repo ===`** (**`root:`**, **`branch:`**), **`=== path-scope ===`**, **`=== status ===`**, **`=== porcelain ===`**, **`=== untracked-sample ===`**, **`=== ignore-check ===`**, **`=== diff-stat (unstaged|staged) ===`**, **`=== git-inspect-done ===`**. Default: orchestrator repo at workspace root. **`--repo <dir>`** runs all git probes in that working tree (ROAD-48 **target** for branch consent when **`attach-target.txt`** is set). |
| **`scripts/tools/log-gate.sh`** | **`GATE:`** / telemetry | Subcommands write via **`session-memory.sh --ticket <ticket-folder> write`**; **no** structured stdout contract beyond errors — see **`log-gate.sh --help`**. |
| **`scripts/hooks/pipeline-finish.sh`** | **§9 Finish** | Human-readable sections: **`=== pipeline-finish ===`**, **`=== git-status (brief) ===`**, **`=== commit ===`** / **`=== git-add-commit ===`**, **`=== git-push ===`**, **`=== audit-session-trace ===`**, **`=== pipeline-finish-done (audit exit N) ===`**. Runs **`python3 scripts/tools/audit-session-trace.py`** internally — orchestrator **must not** invoke that Python entry separately. Flags: **`--no-commit`**, **`--commit-message`**, **`--commit-file`**, **`--push true|false`**, **`--pre-audit-delay-seconds`**, then **`--`** for extra audit args. |
| **`scripts/hooks/pipeline-commit.sh`** | **Commit policy** (mid-pipeline) | **`git add` / `git commit` only** when ticket **`_state.json.commit_policy`** authorizes (`per_task` / `per_phase`). **No** push, **no** audit. Flags: **`--commit-message`**, **`--commit-file`**, optional **`--repo`**. See run-pipeline **Commit policy**. |

**Lifecycle:** **`scripts/tools/session-memory.sh --ticket <folder>`** — **`ensure`**, **`read`**, **`write`**, **`clear`**, **`active-path`**, **`session-root`**, **`detach-workspace`**, **`phase-security-path <N>`**, **`write-trace-anchors [--resume]`**, **`trace-hash-root`**. Every command requires **`--ticket`**. The session-init hook does not read a timeline.

### Session trace anchors

Orchestrated **`/run`** writes **trace anchors** into **`<ticket-folder>/_run/timeline.md`** so **`scripts/tools/audit-session-trace.py --ticket`** can correlate the correct **`~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`** tree. **`pipeline-init.sh`** calls **`write-trace-anchors`** (with **`--resume`** when resuming).

**Canonical line formats** (one line each; start at column 0; appended under **`## Timeline`** after that header — **append-only**, stable relative to later pipeline writes). Values are single-line; parsers should trim surrounding ASCII whitespace on the value side.

| Line prefix | Value | Meaning |
|-------------|-------|---------|
| **`SESSION_START:`** | UTC timestamp | Start of the trace window for this run. **Format:** ISO-8601 **`YYYY-MM-DDTHH:MM:SS.sssZ`** (milliseconds, **`Z`** = UTC). Example: **`SESSION_START: 2026-04-10T23:45:12.345Z`**. |
| **`PROJECT_HASH:`** | Directory name | **Exactly** the stdout of **`scripts/tools/cursor-project-hash.sh`** run with one argument: the **trace root** (single line, no newlines). Default trace root is the orchestrator **`$ROOT`**; **ROAD-48:** when **`attach-target.txt`** is present, the trace root is the **target** repo root (see paragraph below). Matches **`~/.cursor/projects/<PROJECT_HASH>/`**. Example: **`PROJECT_HASH: Users-vivian-lied-GitWorkspace-agentic-workspace`**. |

**Parsing notes for tooling:** Match lines with **`^SESSION_START:\s*`** and **`^PROJECT_HASH:\s*`**; strip one optional space after the colon if present; **`PROJECT_HASH`** must not contain whitespace after trim. **`audit-session-trace.py`** should treat **`SESSION_START`** as the lower bound for **`.jsonl`** **mtime** inclusion (see session trace audit docs).

**`cursor-project-hash.sh` encoding** (macOS/Linux; document if Cursor changes): resolve **`REPO_ROOT`** with **`pwd -P`**, strip one leading **`/`**, replace **`.`** with **`-`**, then replace **`/`** with **`-`**. **`--help`** describes the same; **`--verify`** prints whether **`$HOME/.cursor/projects/<hash>`** exists and whether **`agent-transcripts/`** is present.

**Folder vs `.code-workspace` / multi-root (PROJECT_HASH mismatch):** **`write-trace-anchors`** runs **`scripts/tools/cursor-project-hash.sh`** with one argument: the **trace root**. By default that is **`$ROOT`** (orchestrator — parent of **`scripts/tools/`**, same as **`cursor-project-hash.sh`** with no args). **ROAD-48:** when **`<ticket-folder>/_run/attach-target.txt`** exists (written by **`attach-project.sh`**) with a valid directory path, **`write-trace-anchors`** and **`pipeline-init.sh`** use that **target** root instead so **`PROJECT_HASH`** aligns with the writable repo in a multi-root workspace. The hash still matches **`~/.cursor/projects/<PROJECT_HASH>/`** only when Cursor’s effective workspace identity matches that path (after **`pwd -P`**). If the user opens a **`.code-workspace`** without **`attach-target.txt`**, a **multi-root** parent folder, or a **different clone path**, Cursor may store transcripts under a **different** directory name than the computed hash. Symptom: **`audit-session-trace.py`** finds **no** matching **`.jsonl`** files. Mitigations: use **`attach-project.sh`** so **`attach-target.txt`** is set; inspect **zero-match diagnostics** in **`audit.log`**; compare hashes manually; or run **`cursor-project-hash.sh`** from the path Cursor shows as the workspace root.

**Run-pipeline §1 / §5 vs multi-root (ROAD-48):** For **`/run`** **§1** branch consent, the orchestrator runs **`scripts/tools/git-inspect.sh --repo <TARGET_ROOT>`** when **`attach-target.txt`** supplies **`TARGET_ROOT`** (the writable repo). Without multi-root attach, use **`git-inspect.sh`** with no **`--repo`** (orchestrator repo). For **§ 5** **`Task(dev|sre|data)`**, set the **`Task`** **`working_directory`** to **`TARGET_ROOT`** when **`attach-target.txt`** is present; pass **`WORKTREE_PATHS`** only for worktrees **inside** that repo. **§2 Init** (**`pipeline-init.sh`**) always runs from the **orchestrator** root — see **`.cursor/skills/run-pipeline/SKILL.md`** **§1** and **§2**.

**Idempotence and `--resume`:** If both **`SESSION_START:`** and **`PROJECT_HASH:`** lines already exist in **`timeline.md`**, **`write-trace-anchors`** is a no-op (repeat invocations safe). **`--resume`** does not rotate the session id; if anchors are **present**, **`write-trace-anchors`** no-ops. If **`--resume`** is passed and anchors are **missing** (unusual), the command **does not** write new anchors (avoids splitting the trace window); the orchestrator should treat that as a configuration gap.

**Pre-plan handoffs:** **`session-handoff.sh --ticket <ticket-folder>`** writes under **`<ticket-folder>/pre-plan/`**, a sibling of **`_run/`**. It does not use **`session-root`**. Commands: **`write-handoff merged`**, **`write-handoff specialist <name>`**, **`write-handoff review`**, **`write-handoff gate`**. Specialist **`name`** is kebab-case (built-ins such as **`system-design`**, **`repro`**, **`jira`**, **`confluence`**, **`glean`**, or a registered project skill or agent name). Content can be a file path or stdin (use **`-`** for stdin). Each file gets minimal YAML frontmatter (**`kind`**, **`written`** timestamp, and **`specialist`** for specialist files). **Orchestrator responsibility:** after each pre-plan **merge**, write **`pre-plan/merged-brief.md`**; after each specialist **`Task`** completes, write **`pre-plan/specialists/<name>.md`** with a **capped** snapshot; after the reviewer and the scrum gate, write **`review.md`** and **`gate.md`**. The merged brief labels grounding claims **`[executed]`**, **`[code]`**, or **`[inferred]`**, and lists scope-determining inferences under **Unverified premises**. When one of those premises cannot be confirmed by a file read or a documented run, the scrum gate stops with **ASK_USER** and a three-part **Human check** (found, expected, what the human must return). A fact the human supplies is recorded as **Resolved at gate** in the merged brief. Do not write these files by hand under **`_run/`**.

**Mid-run specialist files:** Same **`pre-plan/specialists/`** tree; use **non-colliding** paths or filenames for **`REQUEST_MAIN`**-driven **`Task(mcp-*)`** (see table row **mid-run** above and skill **§ 5**). Prefer a subdirectory (**`pre-plan/specialists/mid-run/`**) or a stable suffix pattern so pre-plan **`{glean,arc,jira,confluence,gitlab}.md`** remain the wave artifacts.

**Persistence contract (waves skipped vs specialists):**

| Situation | **`merged-brief.md`** | **`pre-plan/specialists/*.md`** |
|-----------|----------------------|----------------------------------|
| Normal two-wave run | After each merge step that feeds **`Task(plan)`**; final file reflects Wave 1 + Wave 2 combined, summarized | One file **per specialist that ran** only — no empty placeholders |
| **Wave 1 skipped** (triage lists neither **`glean`** nor **`arc`**) | Still write after **merge + gate** (post-triage or empty Wave 1 merge): body should reflect that Wave 1 was omitted and what was merged for Wave 2 / final handoff | **No** **`glean.md`** / **`arc.md`** unless those **`Task(mcp-*)`** actually ran |
| **Pre-plan skipped** (**`--skip plan`**) | Usually absent — no pre-plan segment | Usually absent |

Scripts do not auto-delete stale specialist files from an earlier run; the orchestrator overwrites or creates files for the current pre-plan only.

**Retention:** `_run/` lives and dies with the ticket folder. Nothing is deleted on a timer.

**`--resume`:** Read **`<ticket-folder>/_run/timeline.md`**, find the last **`GATE:`** or **`FAILURE:`** entry, and continue from the next step. For **which** **`GATE:`** shapes apply after plan vs implementation vs QA, and how **`GATE: impl | DONE | phase: k`** orders multi-phase **`/run`** recovery, see **`.cursor/skills/run-pipeline/SKILL.md`** (**Interaction with `--resume`**, **§ 6**).

### Local auditing

`_run/` is part of the ticket folder. To **inspect** what happened in a pipeline run:
- **Active session root:** `scripts/tools/session-memory.sh --ticket <ticket-folder> session-root` (workspace-relative path to **`<ticket-folder>/_run/`**).
- **Proof pre-plan ran:** **`<ticket-folder>/pre-plan/merged-brief.md`** and/or **`pre-plan/specialists/*.md`** (only files for specialists actually invoked), plus **`pre-plan/review.md`** and **`pre-plan/gate.md`** after the review gate. These are siblings of **`_run/`**, not inside the session root. Empty or missing **`pre-plan/`** means pre-plan did not run, was skipped (**`--skip plan`**), or the orchestrator did not write handoffs.
- **Proof codebase-explorer ran:** under **`artifacts/explorer/`**, one or more **`.md`** files after **`REQUEST_MAIN: codebase-explorer`** (and **`EXPLORATION:`** or equivalent in **`timeline.md`**). Absent if no exploration escalation occurred.
- **Proof QA prep (§ 7.0) ran:** after a full **`/run`** that executed **`Task(qa)`** (**`--skip qa`** absent), list **`artifacts/scanners/`** — expect **`spec-validator.md`** and **`security-scanner.md`**. Missing scanner output when QA ran implies the orchestrator skipped **§ 7.0** (invalid per skill **Invalid completion**). If **`--skip qa`**, **`artifacts/scanners/`** is not required.
- **Gate / resume evidence:** lines in **`timeline.md`** (under **`## Timeline`**) such as **`GATE:`**, **`FAILURE:`**, **`PIPELINE: COMPLETE`**, optional **`COMMIT_SUGGESTIONS:`** / **`PUSH_CONFIRMED:`** (Finish audit lines). For a successful Finish, **`PIPELINE: COMPLETE`** is the **last** **`session-memory.sh --ticket <ticket-folder> write`** for the run (see run-pipeline **§ 9**). **Resume** uses **`GATE: impl | DONE | …`** (and plan / final-scrum gates); **§ 5–§ 6** also emit parseable **`impl | START`**, **`impl | DONE`**, and **`impl-review | GATE | …`** for operator timelines (see the skill — not duplicated here).
- **Finish UX (orchestrated):** When **`AskQuestion`** is available, Finish uses the **tool first** for commit / push / MR prompts; chat-only Finish walls are **not** the primary path. Actual **`git`** + **`audit-session-trace.py`** run via **`scripts/hooks/pipeline-finish.sh`** per skill **§ 9**. See **`.cursor/skills/run-pipeline/SKILL.md`** **§ 9** — **Tool-first Finish** and **Finish script**.
- **Trace anchors:** **`SESSION_START:`** and **`PROJECT_HASH:`** in **`timeline.md`** (see **Session trace anchors** above). Written during **§2 Init** inside **`scripts/hooks/pipeline-init.sh`** (which calls **`session-memory.sh --ticket <ticket-folder> write-trace-anchors`**); they bound which local Cursor transcript files belong to this run.
- **`docs/audit.log`:** Hook/session events appended locally (not a substitute for session **`timeline.md`**; different purpose — security and workflow markers). **`scripts/tools/metrics.sh`** can aggregate local usage when configured; nothing is sent off-machine by default.
- **`audit.log`:** Under **`<ticket-folder>/_run/`**, written when **`scripts/hooks/pipeline-finish.sh`** runs **`scripts/tools/audit-session-trace.py`** at **Finish** (orchestrated **`/run`**, before **`PIPELINE: COMPLETE`**). Policy is **append-only**: each Finish run adds one bounded section (UTC **Finished** timestamp), never truncating the whole file. See **`audit-session-trace.py --help`**. The orchestrator **must not** invoke **`python3 …/audit-session-trace.py`** outside **`pipeline-finish.sh`** for the normal Finish path.

**Finish audit delay (optional):** Pass **`--pre-audit-delay-seconds N`** to **`pipeline-finish.sh`** (forwarded to **`audit-session-trace.py`**) **only at Finish** if JSONL flush timing requires it. Keep **`N=0`** unless you see repeated zero-match audits; do not add sleeps elsewhere in the pipeline by default.

**Pre-flight / previous-run analysis (optional):** Compare **`PROJECT_HASH`** in this ticket's **`timeline.md`** with **`cursor-project-hash.sh`**. A second audit against another ticket's `_run/` is a fallback when the same-run Finish transcript stays empty. It is not a default Init step.

**Isolation:** The audit utility reads **`PROJECT_HASH`** only from the active session’s **`timeline.md`** and **selects** transcript files from **`$HOME/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`** using the **mtime** window. It does **not** merge other projects into the **payload** for a successful match. When **no** **`.jsonl`** qualifies (or the directory is missing), **zero-match diagnostics** include a **bounded** listing of other **`~/.cursor/projects/<hash>/agent-transcripts/`** trees (see **`audit-session-trace.py --help`** epilog for caps). **`.jsonl`** files are included in the primary sweep only when filesystem **mtime** is **on or after** **`SESSION_START`**. Concurrent **`/run`** sessions in **other** repo checkouts use different **`PROJECT_HASH`** values and do not cross-leak into the primary sweep. Validate with the **manual** procedure below.

### Parallel stress test (manual)

**Purpose:** Prove **two-repo isolation**: overlapping orchestrated **`/run`** sessions in two different workspace roots must not cause Repo A’s **`audit.log`** to reference Repo B’s **`PROJECT_HASH`** or B-only transcript artifacts.

**Setup**

- Two terminals (or two Cursor windows), each workspace opened at **Repo A** and **Repo B** respectively. Use **different** clone paths so **`PROJECT_HASH`** differs (mandatory precondition).
- From each repo root, print the hash: **`scripts/tools/cursor-project-hash.sh`**. Record **`PROJECT_HASH_A`** and **`PROJECT_HASH_B`**. Assert **`PROJECT_HASH_A` ≠ `PROJECT_HASH_B`** before starting — if they match, you are not testing cross-repo isolation.

**Procedure**

1. Start overlapping non-resume **`/run`** sessions so both pipelines are active through at least one **§9 Finish** that runs **`audit-session-trace.py`** (timing overlap is what stresses isolation).
2. After Repo A finishes (or at least after A’s Finish audit), in **Repo A** resolve the session directory: **`scripts/tools/session-memory.sh --ticket <ticket-folder> session-root`** and open **`audit.log`** under that path.

**Assertions (Repo A only)**

- The log and anchors are consistent with **Repo A**: **`timeline.md`** for A’s session contains **`PROJECT_HASH:`** equal to **`PROJECT_HASH_A`**; **`audit.log`** must not contain the literal string **`PROJECT_HASH_B`** (nor a **`PROJECT_HASH:`** line with B’s value).
- **Transcript filenames:** If you list **`$HOME/.cursor/projects/<PROJECT_HASH_B>/agent-transcripts/*.jsonl`**, none of those **basenames** should appear in Repo A’s **`audit.log`** (B-only files must not be attributed to A’s sweep).

**Automation:** **Manual** only for this procedure unless a follow-up adds a scripted harness (none required here).

### Audit payload accuracy (qualitative)

Compare reported **token counts**, **truncated excerpts**, and **file hints** in **`audit.log`** against **spec-sized** orchestration inputs — **least privilege**, same *spirit* as **plan-segment context slicing** (bounded **`Plan segment feedback`**, condensed **`Pre-plan context:`**, no whole-transcript replay). The audit utility must not imply a whole-repo scan.

**Checklist (qualitative)**

1. **Anchors:** In **`timeline.md`**, **`PROJECT_HASH:`** matches **`cursor-project-hash.sh`** stdout for **this** repo root only; the Finish section in **`audit.log`** should align with that hash and with **`~/.cursor/projects/<PROJECT_HASH>/agent-transcripts/`** — not paths under a sibling **`~/.cursor/projects/<other-hash>/`**.
2. **Volume sanity:** Totals and excerpt sizes should look like **bounded JSONL fields** from the run window, not like every source file in the repository was ingested. If numbers are orders of magnitude beyond plausible **`Task`** / orchestrator context for the spec, treat as a red flag and verify caps in **`audit-session-trace.py`**.
3. **Path spot-check:** File paths mentioned in the log (if any) should resemble **work touched in the session** (e.g. spec paths, scripts under change) — not arbitrary bulk globs across unrelated trees.
4. **Time window:** **`SESSION_START:`** in **`timeline.md`** should bound **mtime** inclusion; Finish timestamps should be after the run’s trace window start.
5. **Plan-segment alignment:** Like plan-segment slicing, telemetry should reflect **narrow** inputs to **this** pipeline — not a dump of all prior chat or full-repo indexing. See **Context slicing (plan segment)** earlier in this doc.

### Manual verification (pre-plan orchestration)

Use this checklist when validating **orchestrator docs** and **live `/run`** behavior (no CI substitute for branch UX and **`Pre-plan context:`** shape).

- **(a) Protected branch — soft prompt at §1, hard gate at §5** — Start **`/run`** on a **protected** branch (`main`, `master`, `develop`, `release/*`). Expect **§1** to only ask a **soft, informational** question (switch for analysis, or continue on the current branch) — **not** a hard stop — and Init, pre-plan **`Task(mcp-*)`**, and **`Task(prd)`**/`Task(spectech)`/`Task(tasks)` proceed regardless (they only write the ticket folder, in the workspace root — not a child/target repo). The **hard stop** (abort, switch, or an **approved** new branch name) fires later, immediately **before the first § 5** `Task(dev|sre|data)` — see skill **§1 Ordering** and **§5 Pre-check — branch gate**.
- **(b) Jira-only / Wave 2-only (no Wave 1)** — Use a goal where **`Task(pre-plan-triage)`** lists **no** Wave 1 sources (**neither** **`glean`** nor **`arc`**) but **may** need **`jira`** / **`confluence`** / **`gitlab`**. Expect **no** **`Task(mcp-glean)`** or **`Task(mcp-arc)`** — **merge + gate** after triage (or an empty Wave 1 merge), then Wave 2 only as gated.
- **(c) `Pre-plan context:` vs raw MCP JSON** — After pre-plan, inspect the **`Task(plan)`** prompt or orchestrator log: **`Pre-plan context:`** must be a **short, summarized** brief (bullets / pointers), **not** a paste of full MCP tool JSON or unbounded dumps. On disk, **`pre-plan/merged-brief.md`** is the **bounded** merged artifact; **`pre-plan/specialists/*.md`** are **capped** snapshots — see **Local auditing** above and **Persistence contract** in **Session storage**.

### Manual verification (plan segment)

Use this checklist when validating the **plan segment** (between optional pre-plan and **§ 5** implementation). Authoritative procedure remains **`.cursor/skills/run-pipeline/SKILL.md`** (**§ 3–4**, **Manual step gates**).

| Test / theme | What to verify (manual / live `/run`) |
|----------------------|----------------------------------------|
| **Test Anti-Nesting** | Use a **`/run`** goal that targets an **unfamiliar or un-indexed** directory so **`Task(plan)`** cannot orient from KB/ARC alone. Expect **`REQUEST_MAIN:`** (or **`QUESTION:`**) in **`Task(plan)`** output — **not** a nested **`Task(codebase-explorer)`**. The **orchestrator** (main session) should then run **`Task(codebase-explorer)`**, write a **bounded** markdown file under **`<ticket-folder>/_run/explorer/`**, append a **`session-memory.sh`** trace line (e.g. **`EXPLORATION:`** path + one-line reason), and **re-invoke** **`Task(plan)`** with the **artifact path** and/or a **capped excerpt** — **not** merging an **unbounded** scout summary into the **next** **`Task(plan)`** prompt alone. |
| **Test Context Slicing** | Force **`Task(plan-reviewer)`** below threshold on **attempt 1** (e.g. reject draft). Inspect the **attempt 2** **`Task(plan)`** prompt: it must carry **`Plan segment feedback:`** / sliced content derived from **`PLAN_REVIEW_FEEDBACK:`** (see **`timeline.md`**) — **without** replaying the full loop-1 **`Task(plan)`** transcript or redundant raw pre-plan dumps. |
| **Test the Loop Cap** | Document or simulate **plan-reviewer** staying below threshold through **three** inner-loop iterations. Expect **no** automatic fourth plan-review iteration; orchestrator uses **`AskQuestion`** (or chat fallback: Proceed anyway / Abort / Provide guidance) and an **`ESCALATION:`** line in **`<ticket-folder>/_run/timeline.md`** for plan-segment max iterations (see skill). Matches **`--max-plan-iterations`** (default **3**). |
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

Order matches **`.cursor/skills/run-pipeline/SKILL.md`** (**§1** Preconditions → **§2** Init → optional pre-plan → Plan segment → …). **§1** is informational only (read-only branch detection + a soft switch-or-continue prompt) and does **not** block **§2 Init**, **Pre-plan context**, or **`Task(prd)`**/`Task(spectech)`/`Task(tasks)`. The hard protected-branch gate (consent resolved or run aborted) sits at **§5 Pre-check**, immediately before the first implementation `Task`.

```
User → Main session agent (reads run-pipeline skill)
     → §1: repo/branch awareness (git-inspect.sh; soft "switch for analysis or continue?" prompt — no hard gate yet)
     → §2 Init (pipeline-init.sh --ticket: ensure if not --resume; write-trace-anchors; apply-models snapshot; timeline read; optional knowledge-source note)
     → [optional] Task(pre-plan-triage)
     → Wave 1: parallel Task(mcp-glean) + Task(mcp-arc) (each only if triage lists it; omit whole wave if neither) → merge
     → Gate → Wave 2: Task(mcp-jira) | Task(mcp-confluence) | Task(mcp-gitlab) (each only if triage or merged brief needs it) → final merge (summarized; merged-brief.md on disk)
     → Task(plan) (condensed **Pre-plan context:**) ↔ Task(plan-reviewer) self-heal (max iterations) → Task(scrum) plan gate
     → §5 Pre-check — branch gate: protected branch? stop (abort / stay / create + approve a name); default no worktree
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
5. **Final merge** — One **summarized** merged external brief (bounded text — align with on-disk **`merged-brief.md`**). Persist **`<ticket-folder>/pre-plan/merged-brief.md`** with **`session-handoff.sh --ticket <ticket-folder> write-handoff merged`**.
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

This workspace is a FRAMEWORK repo. App projects (e.g. `myapp/`, `payments-api/`) are independent git repos cloned inside the workspace root via `/clone`, which excludes each one from the workspace's own history with a `.gitignore` entry. They exist on disk but are NOT part of the workspace git history. The pipeline reads framework files from the workspace and makes code changes in the working repos. Worktrees are created in the working repos for isolation.

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

`mode`, `confidence_threshold` (default 75), `qa_iteration` (0), `max_qa_iterations` (flag or 3), `max_review_loops` (flag or 2), `current_step`, `skipped_steps`, `scores = {}`, `model_strategy` (flag or `balanced`), `budget` (flag or none), `cost_estimate = 0`, `escalations = []`, `model_plan = {}`, `models_used = []`, `snapshot_path` (default `docs/local/.model-snapshot`, overridable via `APPLY_MODELS_SNAPSHOT`), **`manual_step_gates`** (`true` when `/run` includes **`--manual`** — orchestration pauses; **not** manual model mode).

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

Persist: `session-memory.sh --ticket <ticket-folder> write "MODEL_PLAN: {compact JSON or table}"`.

### --resume recovery

Read **`<ticket-folder>/_run/timeline.md`**, find the last **`GATE:`** or **`FAILURE:`** entry, resume from the next step. Previously completed gates are not re-run. **Manual gates (`--manual`):** if the run stopped **at** a manual gate (user had not answered), **`--resume`** **re-offers** that gate per the skill. If the session file is missing or corrupt, start fresh and warn. Re-snapshot or reload `model_plan` / `models_used` from session memory if recorded there.

## Model Escalation Logic

When a reviewer returns a score below threshold, consider **adaptive escalation before rework**. Consult `docs/model-catalog.md` only for targeted ID picks.

### Escalation Rules

1. **Eligibility:** Has this step already been escalated? Under `quality` strategy at premium+, escalation may be unnecessary — go to rework/ASK_USER unless a specialty model helps.
2. **Adaptive target:** Infer the weak factor from the reviewer report; pick a model ID suited to that gap (security findings → premium reasoning; shallow spec critique → stronger arch model; infra gaps → SRE-class ID). Generic reports → one-tier-higher ladder.
3. **Apply:** `apply-models.sh <agent> <new-id>`, re-run the step once. Log: `session-memory.sh --ticket <ticket-folder> write "MODEL_ESCALATION: {step} | {from} → {to} | reason | score {N}%"`. **Not used in manual mode** — escalation goes to rework / ASK_USER without changing frontmatter.
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

- **Subagent failure:** Stop. `session-memory.sh --ticket <ticket-folder> write "FAILURE: {step} | {error}"`. Return stderr/stdout, failed step, last successful step. Suggest **`/fix`**, **`/do`**, **`/run --resume`**, or re-run **`/run`** (same escape hatch list as **`00-workspace-router.mdc`** and **`.cursor/skills/run-pipeline/SKILL.md`** **Error handling**).
- **Implementation reviewer / scrum failure (§ 6):** **Stop** — do **not** “fail-open” past **§ 6** (implementation review before **§ 7 QA** or **Finish**). Record **`FAILURE:`** or **`REWORK:`** in session memory; suggest **`/fix`**, **`/do`**, **`/run --resume`**, or re-run **`/run`**. Only **`--skip impl-review`** (explicit user opt-in) may skip **§ 6**; if you skip without that flag, **`PIPELINE: COMPLETE`** is **invalid** (same as **`.cursor/skills/run-pipeline/SKILL.md`** **Invalid completion**). **QA** (**§ 7**) has its own persona — do not confuse with implementation **§ 6**.
- **Spec corruption:** Stop; do not guess task lists.
- **Context pressure:** Compact delegation results; re-read only spec slices between steps.

### Self-heal (orchestrated runs)

**`/fix`** (bugs), **`/do`** (ad-hoc mechanical work), **`/run --resume`** (continue after logged gate/failure), or re-run **`/run`** — aligned with the skill; optional MCP availability does not change this list.

## Dynamic model selection vs manual model mode

- **Script:** `apply-models.sh` — bulk sync from **team** `.cursor/models.yml` or **manual** `.cursor/models.user.yml` depending on `use_manual_models`; single-agent `<agent> <model-id>` (refused in manual mode unless `--force`); `--snapshot` / `--restore` / `--restore-agent`; `--dry-run`; `--show-source` (manual vs team). Unknown IDs warn against `docs/model-catalog.md` but still apply.
- **Catalog:** `docs/model-catalog.md` — tier and ID reference for escalation picks when **not** in manual mode (not a cold-start read).
