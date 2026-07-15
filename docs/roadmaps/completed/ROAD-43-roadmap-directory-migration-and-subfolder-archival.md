### ROAD-43: Roadmap Directory Migration & Subfolder Archival

**Priority:** Medium
**Category:** Tooling / UX
**Status:** Completed — 2026-04-10
**Complexity:** Medium
**Dependencies:** None

#### Description

The former single-file roadmap was migrated to a directory model: one Markdown file per **ROAD** id, with completed items under **`docs/roadmaps/completed/`**, to improve readability and reduce merge conflicts. Orchestrator **`ROAD-NN`** context loads from **`docs/roadmaps/ROAD-NN-*.md`** (active root first, then **`completed/`**).

#### Goal

- **Directory Structure:** `docs/roadmaps/` for active items (Planned/In-Progress) and `docs/roadmaps/completed/` for shipped items.
- **File Naming:** `docs/roadmaps/ROAD-NN-slug.md` (and same pattern under **`completed/`**).
- **Tooling:** `roadmap-next.sh`, `roadmap-validate.sh`, agents, and **`run-pipeline`** use the directory tree; legacy monolith removed.

#### Deliverables

- [x] **Data Migration:** `docs/roadmaps/` and `docs/roadmaps/completed/` populated; former monolithic blocks split into per-item files.
- [x] **Tooling Update (`roadmap-next.sh`):** Next `ROAD-NN` id from filenames in active + **`completed/`**.
- [x] **Tooling Update (`roadmap-validate.sh`):** Dependencies resolved across all Markdown under the roadmap root.
- [x] **Orchestrator Update:** `run-pipeline/SKILL.md` — **`ROAD-NN`** context from `docs/roadmaps/ROAD-NN-*.md` (active, then **`completed/`**).
- [x] **Cleanup:** Legacy monolith file removed; **README** and verification scripts updated for the directory model.

---
