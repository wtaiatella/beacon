# Project Workspace Contract & Architecture Reference

> **Canonical Workspace Reference for AI Agents & Developers**  
> Shared source of truth across all tools (**Antigravity IDE**, **Claude Code**, **Cursor**).  
> Defines target repositories, dev/prd environments, databases, ports, and architectural conventions.

---

## 1. Workspace Identity & Repositories

<!-- Describe the target repository layout.
Example:
- Monorepo or Multi-repo structure
- Directory paths of child repositories / sub-projects
- Primary git remotes
-->

---

## 2. Environments & Git Workflow

<!-- Define environments (e.g. dev, staging, production), branch strategy, and rules:
Example:
- Dev Environment: directory, active branch, database, execution commands.
- Prd Environment: directory, active branch, release process.
- Branch protections and git commit/merge rules.
-->

---

## 3. Network Ports & Services

<!-- Define ports used to avoid collisions with MCP servers and developer tools:
| Service | Port | Protocol | Purpose / Command |
| :--- | :--- | :--- | :--- |
| MCP / Tools | 3000 | HTTP / TCP | IDE MCP services (e.g., Excalidraw) |
| App Dev | 3100 | HTTP | Dev server (e.g., npm run dev) |
| App Start | 3200 | HTTP | Production build preview (npm start) |
-->

---

## 4. Tech Stack & Environment Variables

<!-- List core technologies, frameworks, databases, and required .env keys -->

---

## 5. Architectural Patterns & Coding Conventions for Agents

<!-- Document project-specific coding standards so AI agents follow existing conventions:
- API Route conventions (auth guards, validation schemas, error format)
- Service layer & ORM / database access rules
- Testing standards and test data cleanup conventions
- Background jobs / workers
-->
