### ROAD-28: Dynamic Model Selection for Pipeline Steps

**Priority:** High
**Category:** Cost / UX
**Status:** Completed
**Complexity:** Large
**Dependencies:** ROAD-27 (completed)

#### Description

ROAD-27 delivered the model catalog, tier framework, and baseline escalation documentation. **ROAD-28** wires **per-run dynamic model selection** into `/run`: a model plan from task analysis, `apply-models.sh` before each delegation, snapshot restore after each step, strategy guardrails, and adaptive escalation with a completion efficiency summary.

Agent frontmatter supports `default`, `inherit`, and specific model IDs (e.g., `gpt-5.3-codex`, `composer-2`, `claude-4.6-opus-high`). Baseline mappings remain in `models.yml`; `/run` overrides per step using `scripts/tools/apply-models.sh` and session snapshots (`APPLY_MODELS_SNAPSHOT` for concurrency).

#### Phase 1: Dynamic Model Selection in /run

- [x] `/run` analyzes the task during planning (Step 1) and produces a **model plan** — a mapping of each pipeline step to a specific model ID, based on:
  - Task complexity (simple config change vs. multi-service architecture)
  - Domains involved (`[dev]` only vs. `[dev]+[sre]+[data]`)
  - Risk indicators from spec frontmatter (confidence weights, threshold overrides)
  - Codebase size and language complexity (from KB or codebase-explorer)
- [x] Before each delegation, `/run` calls `apply-models.sh <agent> <model-id>` to set the optimal model for that specific step
- [x] After each step completes, restore the agent to its baseline model
- [x] The `--model-strategy` flag constrains the model plan:
  - `conservative` — cap at economy/standard tier; prefer cheaper models within capability bounds
  - `balanced` (default) — standard for implementation, economy for reviews, premium only when complexity warrants
  - `quality` — floor at standard tier; use premium for planning and QA
- [x] Log the model plan and actual models used per step to session memory

#### Phase 2: apply-models.sh Enhancements

- [x] Extend `apply-models.sh` to accept single-agent updates: `apply-models.sh <agent> <model-id>` (in addition to bulk apply from `models.yml`)
- [x] Add `apply-models.sh --snapshot` to save current state and `--restore` to return to it (per-session state management)
- [x] Add `--dry-run` flag to preview changes without applying
- [x] Validate model IDs against the catalog (`docs/model-catalog.md`) — warn on unknown IDs
- [x] Guard against concurrent `/run` pipelines: snapshot per session, restore from session snapshot not global defaults

#### Phase 3: Adaptive Escalation

- [x] When a reviewer returns a low score, `/run` doesn't just "go one tier higher" — it picks the specific model best suited to the weak factor (e.g., weak security analysis → pick a model known for security reasoning)
- [x] Track escalation events with before/after model IDs and the reasoning for the choice
- [x] After pipeline completion, emit a model efficiency summary: which models were used, estimated cost, and whether any escalations occurred
- [x] Feed model performance data back into future model plans (e.g., "last time this agent type scored poorly on gpt-5.4-mini, skip it") — *best-effort via completion output calibration hint; no persistent store yet*

#### Notes

- Cursor re-reads agent `.md` files on each subagent invocation, so frontmatter changes via `apply-models.sh` take effect immediately — no restart needed.
- Valid frontmatter `model:` values: `default`, `inherit`, or any specific model ID from `docs/model-catalog.md`. Both `default` and `inherit` are accepted by Cursor.
- The model plan is generated once during planning, but `/run` can adjust it mid-pipeline based on review scores (adaptive escalation).
- This is about optimizing cost-per-quality: a simple typo fix shouldn't burn premium model tokens, but a complex multi-service architecture change should use the best models available.

---
