---
name: gitlab-mr-from-spec
description: "Optional: combine spec-driven MR body text with user-run GitLab actions (Claude Code GitLab plugin or glab). Reinforces no autonomous commit/push/MR. Use when finishing a pipeline or opening an MR from a spec."
---

# GitLab MR from spec (optional)

Use this skill when the user wants a **GitLab merge request** whose body aligns with an **architecture spec** and optional **`/summary`** artifact.

## Non-negotiables

1. **No autonomous mutations** — Do **not** run `git commit`, `git push`, `glab mr create`, or GitLab REST writes. The **main orchestrator** may run **`git commit`** only when **`run-pipeline`** Finish rules say so (user selected an offered message). This skill still generates **text only** for MRs; push/MR remain user-run (see **`run-pipeline`** Finish).
2. **Generate text only** — Produce or point to **`scripts/tools/mr-description-from-spec.sh`** output. For a richer body, set **`SUMMARY_PATH`** to a summary file when invoking the script.
3. **Plugin-first** — Prefer **`docs/reference/gitlab-cursor-workflow.md`**: Claude Code GitLab marketplace plugin + **`create-merge-request`** (or equivalent) after local commits.
4. **`glab` second** — Document example commands with **placeholders** for token, project, and branches; never embed secrets.

## Workflow

1. Resolve the **spec path** (same rules as `/summary`: path, slug, `latest`).
2. Run or describe:  
   `scripts/tools/mr-description-from-spec.sh <spec.md>`  
   Optionally:  
   `SUMMARY_PATH=docs/summaries/YYYY-MM-DD-slug-summary.md scripts/tools/mr-description-from-spec.sh <spec.md>`
3. List **suggested GitLab labels** from spec domain tags (`dev` / `sre` / `data`) as printed by the script.
4. Remind the user to confirm **target branch** and **push** per **`run-pipeline`** Finish.

## References

- **`docs/reference/gitlab-cursor-workflow.md`**
- **`docs/reference/cursor-plugins.md`**
- **`run-pipeline`** skill — Finish section and delegation header item 5
