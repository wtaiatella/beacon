---
name: gitlab-mr-from-spec
description: "Optional: combine spec-driven MR body text with MR create/update via the GitLab MCP after explicit user confirmation. Reinforces no silent commit/push/MR. Use when finishing a pipeline or opening an MR from a spec."
---

# GitLab MR from spec (optional)

Use this skill when the user wants a **GitLab merge request** whose body aligns with an **architecture spec** and optional **`/summary`** artifact.

## Non-negotiables

1. **No silent mutations** — Do **not** run `git commit`, `git push`, or any mutating GitLab action without explicit user confirmation at that step. The **main orchestrator** may run **`git commit`** only when **`run-pipeline`** Finish rules say so (user selected an offered message), may **`git push`** only after an explicit **Yes** to the push prompt, and may create/update the MR **via the GitLab MCP** (`mcp__GitLab__*`) only after explicit confirmation of that step — always presenting the MR title/body for review first (see **`CLAUDE.md`** — Git and GitLab mutations). This skill generates the **MR body text**; the main loop performs the actual create/update once confirmed (see **`run-pipeline`** Finish).
2. **Generate text only** — Produce or point to **`scripts/tools/mr-description-from-spec.sh`** output. For a richer body, set **`SUMMARY_PATH`** to a summary file when invoking the script.
3. **GitLab MCP first** — Once the user confirms, the main loop creates/updates the MR **via the GitLab MCP** (`mcp__GitLab__*`), always presenting the MR title/body for review before calling it. `glab` is **not** used in this workspace (not authenticated); do not suggest it.
4. **Plain language — no internal SDD siglas:** The MR description is read by developers and stakeholders who do not know this workspace's internal spec framework. **Never** include bare internal identifiers as justification or labels: `NFR-N`, `TD-N`, `FR-N`, `SC-N`, numbered task IDs (`T-NNN`), references to spec sections (`spectech.md §4`, `_notes.md`), or any other framework-specific shorthand. **Translate every such reference into plain English** — explain the actual reason, behaviour, or constraint in terms any developer can understand. Acceptance criteria rows must describe the scenario in words, not just an `AC.N` label.

## Workflow

1. Resolve the **spec path** (same rules as `/summary`: path, slug, `latest`).
2. Run or describe:  
   `scripts/tools/mr-description-from-spec.sh <spec.md>`  
   Optionally:  
   `SUMMARY_PATH=docs/specs/{ticket-folder}/summary.md scripts/tools/mr-description-from-spec.sh <spec.md>`
3. List **suggested GitLab labels** from spec domain tags (`dev` / `sre` / `data`) as printed by the script.
4. Once the user confirms the **target branch**, create/update the MR **via the GitLab MCP** (`mcp__GitLab__*`), presenting the title/body for review first; also remind the user to confirm **push** per **`run-pipeline`** Finish.

## References

- **`docs/reference/gitlab-cursor-workflow.md`**
- **`docs/reference/cursor-plugins.md`**
- **`run-pipeline`** skill — Finish section and delegation header item 5
