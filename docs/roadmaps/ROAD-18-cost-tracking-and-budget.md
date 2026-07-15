### ROAD-18: Cost Tracking & Budget

**Priority:** Medium
**Category:** Analytics
**Status:** Planned
**Complexity:** Medium
**Dependencies:** None
**Related:** ROAD-27 (cost tracking data feeds model optimization decisions)

#### Description

Lightweight tracking of model usage and token estimates per session and spec so teams can set budgets and compare persona costs. Provides the observability foundation for ROAD-27's cost optimization strategy.

#### Key Deliverables

- [ ] Convention for logging usage events (session duration, model selected, agent invocations, model tier per step)
- [ ] Per-agent and per-step cost attribution: which pipeline steps consume the most budget
- [ ] Rollup script or spreadsheet-friendly export from `docs/audit.log`
- [ ] Cost-per-spec tracking: compare actual spend across specs of similar complexity
- [ ] Model tier usage breakdown: what percentage of spend goes to each tier (economy/standard/premium)
- [ ] Documentation for budget alerts (manual or scripted thresholds)

#### Notes

- Accuracy depends on provider; estimate ranges are acceptable. Leverage existing audit log timestamps and session data.
- This item provides the *data*; ROAD-27 provides the *optimization strategy* informed by that data. Implement tracking first.
- Consider integrating with Cursor's usage dashboard data if exportable.

---
