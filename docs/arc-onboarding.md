# ARC onboarding (AvaTax Release Central) — ROAD-25

This document separates **two concerns**: (1) onboarding a **GitLab repo** into Release Central indexes in **`avatax-release-central`**, and (2) **using** ARC from **this workspace** via MCP. They are **not** the same step.

## Agentic workspace consumers (Cursor)

If you only use **agentic-workspace** as your framework:

1. **MCP client:** Add the ARC server block to **`.cursor/mcp.json`** (HTTP endpoint, env-backed headers — **no secrets in git**). See **`docs/reference/arc-mcp-workflow.md`** and **`docs/reference/cursor-mcp.md`**.
2. **Server-side:** Your application repo must still be **onboarded** in **`avatax-release-central`** (see below) for ARC search tools to return useful context. Configuring Cursor does **not** register your repo in the index.
3. You **do not** need to change agentic-workspace source to “add a project” — onboarding is **repository work** in **`avatax-release-central`** plus pipeline/index schedules owned by that platform.

## Server-side: `avatax-release-central` repository

Teams add or adjust **project and feature** coverage by editing Python config in the **`avatax-release-central`** repo (exact paths may vary by branch — confirm in-tree):

| File | Role |
|------|------|
| **`projects_config.py`** | Declares which repos / project groups participate in collection and how they map into ARC indexes. |
| **`feature_registry.py`** | Registers tax features and related metadata used for **`search_feat_*`** and cross-references. |

**Do not** commit API tokens, passwords, or host-specific secrets into either repo; follow org standards for CI secrets and local env files.

**Architecture** (high level): see **`avatax-release-central`** — e.g. **`docs/architecture/flow-project-context.md`** when present.

## Confluence indexes (ATPE)

Release Central publishes human-readable index pages for discoverability. One entry point:

- **[AvaTax Release Central Indexes](https://avalara.atlassian.net/wiki/spaces/ATPE/pages/639240306719/AvaTax+Release+Central+Indexes)** (Confluence space **ATPE**)

Use these pages to understand what is indexed and how it maps to ARC search tools; they complement **`docs/reference/arc-mcp-workflow.md`** (tool catalog).

## Local `knowledge/{project}/` fallback

For repos **not** onboarded to ARC (or when MCP is unavailable), teams may still use **`/kb`** and the structure in **`knowledge/`** — see **`.cursor/agents/kb.md`** and **`.cursor/skills/knowledge-base/SKILL.md`**. That path is **secondary** to ARC for AvaTax-related work when ARC applies.

---

## Manual verification checklist (workspace integration)

Use this after changing MCP config, agent docs, or run-pipeline **Init** behavior.

### Configuration and MCP

- [ ] **`./scripts/setup.sh`** exits **0** (JSON parse of **`.cursor/mcp.json`** and related checks).
- [ ] Cursor **Settings → MCP** lists the ARC server (e.g. **`avatax-release-central`**) when the block is present.
- [ ] With network/auth as required, **ARC tools** appear in the MCP tool list / descriptor path and a **sample** `search_*` call returns results or a clear empty response (not a client parse error).

### Agent and orchestration docs

- [ ] **`/plan`**, **`/dev`**, and **`/fix`** (`.cursor/agents/plan.md`, `dev.md`, `fix.md`) read coherently: **ARC first** for AvaTax / Release Central context where applicable; **local KB** + **`codebase-explorer`** as fallbacks.
- [ ] **`.cursor/skills/run-pipeline/SKILL.md` § 2 Init** documents the **knowledge source check**: ARC declared in **`mcp.json`** + optional local **`knowledge/<dir>/_index.md`**, single merged warning when **both** are missing.

### Stale messaging (grep sanity)

From the repo root, no doc should recommend **`/kb`** as the **only** default for ongoing AvaTax knowledge **without** mentioning ARC or local fallback context. Suggested checks:

```bash
# Broad scan — review hits in prose (not JSON URLs containing '/kb')
rg '/kb' --glob '*.md' --glob '*.mdc' .
```

Expect **`/kb`** in: deprecated **`kb`** agent, **`knowledge-base`** skill, router “fallback” lines, roadmap history, and similar — those should **also** reference **ARC** or **arc-mcp-workflow** where AvaTax primary path is described.

- [ ] **`README.md`** and **`knowledge/README.md`** do not present **`/kb`** as the sole long-term story for AvaTax teams without **ARC** / **`docs/reference/arc-mcp-workflow.md`** pointers.

### Policy

- [ ] Core workflows (**`/plan`**, **`/dev`**, **`/fix`**, **`/run`**) remain usable with **ARC disabled** (fallback to local KB and repo tools).
