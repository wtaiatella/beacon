### ROAD-44: Purge Historical ROAD-NN References & Prevent Future Bloat

**Priority:** Medium
**Category:** Tech Debt / Optimization
**Status:** Completed
**Complexity:** Medium
**Dependencies:** None

#### Description

Over time, historical tracking IDs (e.g., `ROAD-25`, `ROAD-36`) have been hardcoded into permanent agent instructions, rules, file names and scripts (like a script with roadmap-38, road-39, and even a .md on how to manually verify roadmap-38). This bloats the LLM context window, wastes tokens, and makes documentation unreadable. We must purge these historical artifacts from the permanent system state and implement automated guardrails to prevent them from being reintroduced. However, guideline entries like the ones on roadmad.md, which are refering to the format so the roadmaps can be found and created should be kept

#### Goal

- **Scrub the Workspace:** Remove all historical `ROAD-XX` references from `.cursor/rules/`, `.cursor/skills/`, `.cursor/agents/`, and `scripts/`.
- **Rewrite for State, Not History:** Instructions should state how the system works *now*, completely divorced from the roadmap item that originally implemented the feature.
- **Automated Prevention:** Implement a linting rule or Git hook that scans for the `ROAD-\d+` regex and blocks commits/merges if found in permanent prompt files.

#### Deliverables

- [ ] **Audit Rules & Skills:** Scrub `.cursor/rules/` and `.cursor/skills/run-pipeline/SKILL.md`. Remove all bracketed `(ROAD-XX)` references and rewrite sentences to flow naturally.
- [ ] **Audit Agents & Scripts:** Scrub `.cursor/agents/*` and `scripts/tools/*` to remove historical tracking mentions.
- [ ] **Update Linter (`lint-check.sh`):** Add a custom `grep` check to `scripts/tools/lint-check.sh`. It must scan `.cursor/agents/`, `.cursor/skills/`, and `.cursor/rules/` for the regex `ROAD-[0-9]+` and throw a non-zero exit code if found. 
- [ ] **Policy Update:** Add a brief section to `CONTRIBUTING.md` defining the "No Historical Tracking IDs in Prompts" rule.

---
