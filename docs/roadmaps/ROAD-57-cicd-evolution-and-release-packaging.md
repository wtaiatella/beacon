### ROAD-57: CI/CD Evolution & Release Packaging

**Priority:** High  
**Category:** DevOps / CI/CD  
**Status:** In progress  
**Complexity:** Large  
**Dependencies:** None (Can run in parallel with ROAD-56)

#### Description
As the Agentic Workspace prepares for multi-collaborator scaling and wider adoption, the CI/CD pipeline must evolve from simple linting/testing into a robust distribution engine. This roadmap item restructures the pipeline to optimize Merge Request (MR) execution, introduces automated Changelog generation, creates lightweight distribution bundles, and publishes official GitLab Releases. Crucially, the actual creation of a release tag and bundle will remain a **manual** trigger on the `main` branch to ensure maintainer control.

#### Goal
- **MR Optimization & Parallel Tests:** Break apart monolithic test jobs for faster, clearer feedback on Merged Results pipelines.
- **Distribution Bundling:** Package the core workspace (`.cursor/`, `scripts/`, `docs/`) into a clean, fetchable `.tar.gz` artifact, stripped of internal tests and git history.
- **Automated Release Payload:** Upgrade the manual `create-release` job to automatically generate Release Notes and attach the distribution bundle using GitLab's `release-cli`.
- **Onboarding Docs:** Update setup instructions to support "Installation via Release Artifact."

#### Detailed Workflow to Audit & Enforce

**Phase 1: Pipeline Restructuring & Test Parallelization**
- **Objective:** Improve MR pipeline visibility and execution speed.
- **Task:** 1. Add a global `workflow:rules` block to ensure pipelines only run on MRs and the default branch.
  2. Split the monolithic `session-trace-help-smoke` job into logical, parallel jobs (e.g., `test:audit-trace`, `test:git-hooks`, `test:workspace-init`).

**Phase 2: Automated Changelog Generation**
- **Objective:** Translate commits into readable release notes on demand.
- **Task:** Create `scripts/tools/generate-changelog.sh`. This script will find the previous Git tag, parse all commits between that tag and `HEAD`, and format them into a Markdown list. This script will *only* be called during the manual release job.

**Phase 3: The Distribution Bundle (`build-release.sh`)**
- **Objective:** Create the "fetchable" artifact for end-users.
- **Task:** Create `scripts/tools/build-release-bundle.sh`. 
  - Safely copies `.cursor/`, `scripts/hooks/`, `scripts/tools/` (excluding tests), `docs/`, and `README.md`.
  - Compresses this into `agentic-workspace-${VERSION}.tar.gz`.

**Phase 4: Manual Trigger, Automated Payload (`create-release` Job)**
- **Objective:** Preserve maintainer control while eliminating manual data entry.
- **Task:** Overhaul the existing `create-release` job in `.gitlab-ci.yml`.
  - Maintain the `when: manual` and `rules: if $CI_COMMIT_BRANCH == "main"` constraints.
  - When manually triggered, the job executes Phase 2 (Changelog) and Phase 3 (Bundle).
  - Use the `release-cli create` command to automatically generate the GitLab Release, attach the generated `release-notes.md`, and link the `.tar.gz` artifact.

**Phase 5: "Install via Release" Setup Docs**
- **Objective:** Teach users the new, cleaner adoption path.
- **Task:** Update `docs/setup.md`. Add a "Fetch & Install" instruction block demonstrating how to `curl` the latest release tarball and extract it directly into a target repository.

#### Deliverables & Acceptance Criteria
- [ ] **Phase 1:** MR pipelines show discrete test jobs that pass/fail independently.
- [ ] **Phase 4:** Clicking the manual `create-release` button successfully mints a tag, generates a tarball, creates the changelog, and publishes a native GitLab Release page.
- [ ] **Phase 5:** Setup documentation explicitly supports the tarball drop-in method.