# Model plan and apply-models

See `docs/run-pipeline-reference.md` for the full narrative. Summary:

## Team + dynamic (default — `use_manual_models: false`)

- **Snapshot:** `scripts/tools/apply-models.sh --snapshot "$snapshot_path"` before overrides; after each step `--restore-agent <agent> "$snapshot_path"` or `--restore` at end.
- **Baseline:** Seed `model_plan` from `.claude/models.yml` + `--model-strategy` before `/plan` completes; refine after `/plan` from spec domains/risk.
- **Strategies:** `conservative` | `balanced` | `quality` — see main reference for guardrails.
- **Escalation:** One per step when reviewer score &lt; threshold; log `MODEL_ESCALATION:` to session memory.
- **Concurrency:** Distinct `APPLY_MODELS_SNAPSHOT` paths per parallel pipeline if needed.

## Manual mode (`use_manual_models: true` in `.claude/models.user.yml`)

- **No per-step swaps:** Do **not** run `apply-models.sh <agent> <id>` before each delegation; do **not** run `--restore-agent` between steps. The user’s bulk-applied assignments from `.claude/models.user.yml` stay in agent frontmatter for the whole run.
- **Snapshot:** Optional at init for bookkeeping; frontmatter should already match the manual file after bulk apply. `--restore` at end is a no-op if no dynamic overrides ran.
- **Escalation:** Do not apply model escalations via `apply-models.sh` (would fight manual intent). Rework / `ASK_USER` only.
- **Detection:** `scripts/tools/apply-models.sh --show-source` prints `manual` vs `team`.
