---
name: generate-spec
description: "Architecture spec template and generation instructions for the /plan persona. The backbone of Spec-Driven Development (SDD)."
---

# Generate Spec

## When to Use

- Drafting a new architecture spec from a user goal
- Amending an existing spec with new requirements or scope changes
- Any time `/plan` needs to produce or modify a spec file

Output format is **normative**: follow section order and tagging rules exactly.

## Output location and naming

- **Directory:** `docs/specs/` at the workspace root (always).
- **Filename (default):** `{YYYY-MM-DD}-{kebab-slug}-spec.md` (use `created` date for new specs; when amending, keep filename or follow team convention).
- **Optional timestamp affixes:** For active work, collision avoidance, or timeline clarity, you may add a **UTC-style timestamp** as **prefix or suffix** on the kebab slug (still ending in `-spec.md`). Common forms:
  - **`YYYY-MM-DDTHHMMSSZ-`** — e.g. `2026-04-10T2057Z-session-storage-staged-preplan-spec.md` (compact time; `Z` denotes UTC).
  - **`YYYY-MM-DD-HHMM-`** — e.g. `2026-04-10-2057-session-storage-staged-preplan-spec.md` (hour/minute block before the slug).
  Prefer one convention per team; the **default** remains **`{YYYY-MM-DD}-{slug}-spec.md`**.
- **Linters:** Workspace spec linters match **`docs/specs/*-spec.md`** — any of the above patterns is valid as long as the filename ends with **`-spec.md`**.

## Spec template (required order)

### 1. YAML frontmatter

```yaml
---
status: draft
created: {YYYY-MM-DD}
last-updated: {YYYY-MM-DD}
---
```

- `status`: `draft` | `in-progress` | `review` | `completed` | `archived` as appropriate; new work defaults to `draft`.
- Set `created` once; update `last-updated` on every meaningful edit.

**Optional confidence tuning** (add when the spec's risk profile differs from defaults):

```yaml
---
status: draft
created: {YYYY-MM-DD}
last-updated: {YYYY-MM-DD}
confidence:
  threshold: 80
  weights:
    dev: 1.0
    sre: 1.5
    data: 2.0
---
```

- `confidence.threshold` overrides the workspace default (75%). Use higher values for regulated or security-critical work, lower for internal tooling.
- `confidence.weights` set per-domain risk multipliers. Default is 1.0 for all domains. Higher weight = stricter scoring for that domain when `/scrum` aggregates across domains. Set based on where the real risk lives in this spec (e.g., data changes on a payment system → `data: 2.0`).
- See the `confidence-scoring` skill for the full scoring model, calibration thresholds by project type, and trend analysis guidance.
- When omitted, the pipeline uses workspace defaults (threshold 75%, equal domain weights).

### 2. Title (H1)

Clear, concise feature or initiative name.

### 3. ## Overview

One to two paragraphs: what is being built, why it matters, and who benefits.

### 4. ## Scope

Table of repositories involved:

| Repository | Path | Role |
|------------|------|------|

Add rows for every repo touched. For single-repo work, one row is enough.

### 5. ## Goals / Non-Goals

Explicit boundaries: what this spec covers and what it **does not** cover.

### 6. ## Architecture

- Include a **Mermaid** diagram (components and key flows).
- Add prose explaining how components interact, data flow, and major integration points.

### 7. ## Dependencies

External libraries, services, APIs, and third-party systems required (versions or constraints when known).

### 8. ## API Contracts (if applicable)

If the work exposes or consumes APIs: endpoints, methods, auth, and request/response schemas (or links to schema artifacts).

Omit this section only when there are no API surface changes.

### 9. ## Task List

Domain-tagged checkboxes. Rules:

- **Single-repo:** `- [ ] [dev] Task description` (and `[sre]`, `[data]` as needed).
- **Multi-repo:** `- [ ] [dev:repo-name] Task description` (same for `sre`, `data`).
- Use **`### Phase N: Name`** headings when work must be ordered across repos (dependencies between phases).
- **Orchestration note:** When the user runs **`/run`**, the main agent follows **`.claude/skills/run-pipeline/SKILL.md`**: implementation delegations are **phase-scoped**—**at most one spec `### Phase N:` per** `Task(dev|sre|data)` (one phase’s tasks for that domain per delegation), with review gates between phases. Spec authors should **not** assume a single persona delegation will implement multiple phases in one shot. Same **one phase per `Task(domain)`** idea applies across the pipeline: each delegation should receive a **single** phase-sized slice of work, not stacked unrelated phases.
- **Coherent bundles:** Group **`[dev]`**, **`[sre]`**, and **`[data]`** tasks into **small, coherent** bundles per phase—one clear outcome per slice. Prefer **splitting** unrelated work across phases or specs over **mega-tasks** that mix concerns.
- **Context hygiene:** Specs assume the orchestrator passes **minimal** merged context (e.g. **Pre-plan context:**, review feedback)—**not** full session transcripts. Do not design task lists that require personas to relay entire chat histories; keep acceptance criteria and scope self-contained in the spec file.
- Within a phase, parallel tasks are fine unless ordering is stated.
- Tags: `[dev]` application code and app-level scripts; `[sre]` infrastructure-as-code, CI/CD pipelines, Helm charts, K8s manifests, Dockerfiles, operational scripts; `[data]` data pipelines, migrations, ML, analytics.
- Tasks must be **atomic**, **actionable**, and **independently implementable** where possible.
- **Include explicit test tasks** (unit, integration, or E2E as appropriate).

Example (single repo):

```markdown
### Phase 1: Core
- [ ] [dev] Implement feature X in service layer
- [ ] [dev] Add unit tests for X edge cases
```

Example (multi-repo):

```markdown
### Phase 1: Contract
- [ ] [dev:api] Publish OpenAPI change for /widgets

### Phase 2: Consumers
- [ ] [dev:web] Consume /widgets in dashboard
- [ ] [sre:infra] Add api service Helm chart with feature flag disabled by default
```

### 10. ## Testing Strategy

Per domain: types of tests, coverage expectations, and **key test cases** (happy path, failure modes, security-relevant cases).

### 11. ## Acceptance Criteria

Numbered, **verifiable** conditions. Each should be **testable** (observable outcome or measurable check).

### 12. ## Risks & Mitigations

Known risks (technical, schedule, operational) and concrete mitigations.

### 13. ## Open Questions

Unresolved decisions, dependencies on others, and **assumptions** explicitly called out.

---

## Tech-stack detection (discovery)

When scanning the repo(s), map markers to stack for accurate Dependencies and Task tags:

| Signals | Likely stack / notes |
|---------|----------------------|
| `package.json` | Node.js; inspect deps for React, Next.js, Express, Nest, etc. |
| `requirements.txt`, `pyproject.toml`, `Pipfile` | Python; note Django, Flask, FastAPI from deps |
| `go.mod` | Go |
| `pom.xml`, `build.gradle` | Java / Kotlin |
| `Cargo.toml` | Rust |
| `Dockerfile`, `docker-compose.yml` | Containerized delivery |
| `*.tf`, `terraform/` | Terraform |
| `*.yaml` with `apiVersion`, `k8s/`, Helm | Kubernetes |
| `.gitlab-ci.yml`, `.github/workflows/`, `Jenkinsfile` | CI/CD |

Mention detected stack briefly in Overview or Dependencies when it affects tasks.

## Task tagging summary

- **Single-repo:** `[dev]`, `[sre]`, `[data]` only.
- **Multi-repo:** `[dev:repo]`, `[sre:repo]`, `[data:repo]`.
- **Phases:** Use when Repo A must finish before Repo B; document the dependency in Phase titles or task text.

## Amending an existing spec

1. Apply requested task and content changes (append or modify tasks; split/merge if needed).
2. Expand the **Scope** table if new repos are added.
3. Bump **`last-updated`** to today’s date.
4. Set **`status`** to `draft` (or `in-progress` per team policy) while changes are in flight.
5. Add a **change history** note at the bottom of the document, e.g. under `## Change History` or a final subsection: date, author optional, one-line summary of what changed.

## Quality bar before handoff

- [ ] All sections present in order (omit API Contracts only if N/A).
- [ ] Task list includes tests and matches domain/repo tagging rules.
- [ ] Acceptance criteria are numbered and testable.
- [ ] File path is under `docs/specs/` and ends with `-spec.md` (default `{YYYY-MM-DD}-{kebab-slug}-spec.md`; optional timestamp affixes per **Output location and naming**).
