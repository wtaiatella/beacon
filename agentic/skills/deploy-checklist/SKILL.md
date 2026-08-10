---
name: deploy-checklist
description: "CI/CD coverage checklist for the /sre persona. Verifies that the right infrastructure code, pipeline stages, and operational readiness items exist before merging — across 5 environments: dev, qa, int, sbx, prd."
---

# CI/CD Coverage Checklist

## When to Use

- Before `/sre` marks SRE work as complete — verify all infra code, pipeline stages, and operational artifacts exist
- During `/qa` review to check operational readiness for target environments
- Any merge-readiness check for infrastructure or deployment changes

This is a **merge-readiness checklist** — it checks whether the right things exist in the codebase and CI/CD pipeline, not whether a deployment succeeded.

**Important:** Agents never deploy. All deployments are handled by CI/CD pipelines. This checklist ensures the code being merged includes the infrastructure, tests, configuration, and operational artifacts that CI/CD needs to deploy safely.

## How to use

1. Identify **target environment(s)** the code will eventually reach: dev, qa, int, sbx, or prd.
2. Walk the checklist for that tier (and all included lower tiers).
3. Apply **Platform-Specific Checks** when the workload uses that platform.
4. For each item: verify the relevant **code, config, or pipeline definition exists** in the repo — not that it has been executed.
5. Flag missing items in the spec or review output so they are addressed before merge.
6. Items that are genuinely not applicable (e.g., no database = skip migration checks): document the reason.

## Environment model

Five canonical environments in promotion order:

| Env | Group | Purpose |
|-----|-------|---------|
| **dev** | Lower | Developer integration, fast feedback |
| **qa** | Lower | Test verification, automated quality gates |
| **int** | Upper | Full system integration, cross-service validation |
| **sbx** | Upper | Pre-production mirror, stakeholder validation |
| **prd** | Upper | Production, live traffic |

**Grouping flexibility:** The boundary between environments depends on cloud provider, region, site, and account. Common patterns:

- **Fully separated** -- each environment has its own account/subscription/project and infrastructure
- **Combined lower** -- dev and qa share a single lower environment (same account, different namespaces/configs)
- **Combined upper** -- int, sbx, and prd share infrastructure with environment-level isolation (e.g., same cluster, different namespaces; same account, different VPCs)
- **Mixed** -- lower environments combined, upper environments separated (or vice versa)

When environments are combined, **all checks for every contained environment still apply** -- the combination is an infrastructure detail, not a reason to skip checks. Identify which logical environment you are targeting and run that tier's checklist.

---

## Environment tiers

### dev

- [ ] No hardcoded secrets in code or config
- [ ] Basic health check endpoint exists
- [ ] Application builds successfully
- [ ] All unit tests pass
- [ ] Docker image builds (if containerized)
- [ ] Environment-specific config separated from code (env vars, config maps, parameter store)

### qa (includes all dev items plus)

- [ ] Integration tests pass
- [ ] Test data seeded or fixtures available
- [ ] Database migrations tested (up and down)
- [ ] API contract tests pass (if applicable)
- [ ] Environment variables documented
- [ ] Resource limits set (CPU, memory) -- prevents noisy-neighbor in shared lower environments

### int (includes all qa items plus)

- [ ] Cross-service integration test definitions exist (end-to-end flows across dependent services)
- [ ] TLS/SSL configuration present (certs, ingress TLS blocks, or cert-manager resources)
- [ ] Service mesh / network policy manifests applied (if applicable)
- [ ] External dependency config documented (third-party API endpoints, message broker connections, cache config)
- [ ] Performance test definitions or thresholds exist (response time budgets, throughput expectations)
- [ ] Rollback procedure documented (runbook step or automated rollback trigger in CI/CD)

### sbx (includes all int items plus)

- [ ] Production-equivalent resource sizing in manifests (replica counts, CPU/memory limits match prd intent)
- [ ] Load test scenario defined in CI/CD or test suite (if performance-sensitive)
- [ ] Monitoring dashboard definitions exist (Grafana JSON, Datadog monitors, or equivalent)
- [ ] Alert rule definitions exist for key metrics (latency, error rate, saturation)
- [ ] Stakeholder sign-off process documented (if required by process)
- [ ] Data migration script tested locally or in CI with rollback (if applicable)
- [ ] Runbook draft exists covering deploy, rollback, and incident response

### prd (includes all sbx items plus)

- [ ] Runbook finalized and covers: deploy steps, rollback steps, incident escalation, key contacts
- [ ] Rollback plan documented and referenced in CI/CD pipeline (manual or automated trigger)
- [ ] Backup and restore procedure documented (or automated in CI/CD)
- [ ] Change log / change management entry prepared
- [ ] On-call notification step exists in CI/CD pipeline or documented in runbook
- [ ] Gradual rollout strategy defined (canary, blue-green, rolling, or feature flag config in manifests)
- [ ] Post-deploy smoke test definitions exist (health check endpoints, critical path tests)
- [ ] Audit/compliance documentation generated (if regulated)

---

## Platform-specific checks

Use the sections that match the deployment stack.

### Kubernetes

- [ ] Resource **requests** and **limits** set
- [ ] **Liveness** probe configured
- [ ] **Readiness** probe configured
- [ ] Pod **Disruption Budget** set (where availability matters)
- [ ] **HPA** configured (if auto-scaling needed)
- [ ] **Network policies** applied (where required)
- [ ] **Service account** with least-privilege access

### Terraform

- [ ] `terraform plan` reviewed (no unexpected destroys)
- [ ] **State locking** enabled
- [ ] No hardcoded credentials in modules or backend config
- [ ] Modules **versioned** / **pinned**
- [ ] **Destruction prevention** on critical resources (where supported)

### Docker

- [ ] **Multi-stage** build used (where applicable)
- [ ] **Non-root** user in final image
- [ ] Image **scanned** for vulnerabilities (policy-compliant threshold)
- [ ] **Layer** optimization applied (cache-friendly ordering)
- [ ] `.dockerignore` configured

### CI/CD

- [ ] Pipeline **stages** defined (build, test, deploy)
- [ ] **Test gate** before deploy stage
- [ ] **Rollback** trigger or procedure wired (automated or documented manual)
- [ ] **Secrets** from CI/CD secret store (not plaintext in YAML)
- [ ] **Deployment notifications** configured

---

## Merge-readiness decision

| Outcome | Rule |
|---------|------|
| **Ready** | Every item required for the target environment(s) has the corresponding code, config, or pipeline definition in the repo — or is documented as N/A with justification. |
| **Not ready** | Required items are missing from the codebase. Flag them in the review so they are implemented before merge. |

**Note:** This checklist does not gate deployment — CI/CD does that. This gates whether the code is *complete enough* to merge, so CI/CD has everything it needs to deploy safely.

---

## Quick reference

- **dev:** fast feedback, secrets hygiene, build, unit tests, containers if used.
- **qa:** test rigor, integration tests, migrations, API contracts, resource limits.
- **int:** cross-service integration, TLS, external deps, rollback tested, performance baseline.
- **sbx:** production-mirror validation, load testing, monitoring, alerts, stakeholder sign-off.
- **prd:** runbooks, rollback plan, backups, change management, on-call comms, controlled rollout.

**If environments are combined** (e.g., single lower for dev+qa, single upper for int+sbx+prd): apply the **highest** tier's checklist for the combined environment. The grouping is an infrastructure detail -- quality gates don't collapse.
