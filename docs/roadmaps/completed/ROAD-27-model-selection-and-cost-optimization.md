### ROAD-27: Model Selection & Cost Optimization

**Priority:** High
**Category:** Cost / UX
**Status:** Completed
**Complexity:** Large
**Dependencies:** ROAD-13 (completed)

#### Description

5-tier model catalog (nano through max) spanning a 150x cost range, with progressive model escalation via confidence scoring, `--model-strategy` and `--budget` flags for `/run`, model-aware reviewer scoring, and cost visibility through metrics and session verification.

Full model registry and pricing in `docs/model-catalog.md`.

#### Deliverables

- [x] `docs/model-catalog.md`: 70+ Cursor models with pricing, tier classification, agent audit, escalation ladder, Auto/Composer evaluation
- [x] `.cursor/models.yml` + `scripts/tools/apply-models.sh`: centralized model assignment config with one-command apply
- [x] `/run` orchestrator: `--model-strategy` flag (conservative/balanced/quality), `--budget` flag (warn-only), model escalation logic before rework, cost tracking with token estimates
- [x] Confidence scoring skill: model-aware scoring section with escalation-vs-rework recommendations
- [x] Router rule: Model Selection section documenting tiers, session guidance, escalation, cost visibility
- [x] `audit-log.sh`: optional model_tier column (backward-compatible)
- [x] `session-verify.sh`: session cost summary from audit log tier data
- [x] `metrics.sh models`: model tier distribution and escalation frequency reporting
- [ ] Cost comparison table in onboarding guide *(deferred — ROAD-19)*
- [ ] ROAD-18 integration for historical cost analysis *(deferred — ROAD-18 not yet implemented)*

#### Notes

- Dynamic model selection for **`/run`** (run-pipeline skill) is specified in `.cursor/skills/run-pipeline/SKILL.md` and `docs/run-pipeline-reference.md` (ROAD-28): model plan, per-step `apply-models.sh`, snapshot/restore, adaptive escalation, and completion summary.
- Agent frontmatter accepts `default`, `inherit`, or specific model IDs (e.g., `gpt-5.3-codex`, `composer-2`, `claude-4.6-opus-high`). The `default` / economy-ID split remains the baseline in `.cursor/models.yml`; `/run` overrides per step via `apply-models.sh` using the session snapshot for restore.

---
