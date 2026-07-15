# Roadmap directory layout (ROAD-43)

The shared workspace backlog is split into one Markdown file per roadmap item instead of a single monolithic file.

## Folders

| Location | Contents |
|----------|----------|
| **`docs/roadmaps/`** | Items whose **Status** field indicates **Planned**, **In progress** / **In-Progress**, or any state that is not “completed” (case-insensitive). |
| **`docs/roadmaps/completed/`** | Items whose **Status** field **starts with** Completed (including notes after an em dash or parenthetical dates). |

## Filenames

Pattern: **`ROAD-NN-short-title-in-kebab-case.md`**, where `NN` is the id from the heading `### ROAD-NN: Short Title` and the slug is ASCII kebab-case derived from that short title.

## Migration notes

- Historical split (ROAD-43 Phase 1) used a legacy monolithic file; the source of truth is now this directory tree (**`roadmap-validate.sh`**, **`roadmap-next.sh`** default **`docs/roadmaps`**).
- If a block had **no** Status line, it was placed in the **active** root (`docs/roadmaps/`).
- Section headings in the old file (`## Completed` / `## Planned`) are not authoritative; **only** the per-item **Status** line determines `completed/` vs active.
