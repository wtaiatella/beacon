### ROAD-24: GitLab Integration Enhancements

**Priority:** Medium
**Category:** Integration
**Status:** Completed (2026-04-10)
**Complexity:** Medium
**Dependencies:** None

#### Description

Deeper integration with GitLab beyond the CI pipeline: MR **body** text and labels aligned to specs, optional **`/summary`** section, branch naming guidance for **`--branch`**, and documented user-run flows (Cursor GitLab plugin or `glab`). Agents **do not** auto-create MRs or call mutating APIs; Finish prompts and optional **`scripts/tools/mr-description-from-spec.sh`** / **gitlab-mr-from-spec** skill support human-in-the-loop shipping.

#### Key Deliverables

- [x] MR description helper: `scripts/tools/mr-description-from-spec.sh` (stdout for paste or `glab --description "$(…)"`) plus **gitlab-mr-from-spec** skill; MR creation remains **user-run** per workspace rules
- [x] MR body template from spec title, **Task List**, and **Acceptance Criteria**; optional **Summary** section via `SUMMARY_PATH`
- [x] Branch naming: `feature/{spec-slug}`, `hotfix/{spec-slug}` in **run-pipeline** (`{spec-slug}` = dated filename minus `YYYY-MM-DD-` and `-spec.md`); `--branch` is a hint only — explicit approval before create/switch
- [x] Suggested GitLab labels from spec domain tags (`dev`, `sre`, `data`) in script output

#### Notes

Optional **`glab`** or GitLab plugin/MCP — not all teams use GitLab. Tokens stay out of repo; no autonomous **`git`**, push, or MR API calls from orchestration.

---
