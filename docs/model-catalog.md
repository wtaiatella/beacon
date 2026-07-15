# Model Catalog

> Reference document for Cursor model selection in the agentic workspace.
> Pricing as of April 2026. Cursor may change pricing and model availability at any time.
>
> **Subscription limits / Auto:** If you need **session Auto** or **`default` / `inherit` everywhere** (no per-step pipeline overrides), set **`use_manual_models: true`** in `.cursor/models.user.yml` and run bulk `apply-models.sh` — see README *Model configuration* (ROAD-36).

## Model Tiers

Five tiers classify models by cost and capability. Use the tier that matches task complexity — don't pay for reasoning you don't need.

| Tier | Input per 1M | Output per 1M | Use When |
|---|---|---|---|
| **nano** | $0.20–$0.30 | $1.25–$2.50 | Formatting, simple validation, file listing, trivial checks |
| **economy** | $0.50–$1.00 | $2.50–$5.00 | Exploration, simple reviews, summarization, ad-hoc tasks |
| **standard** | $1.25–$2.00 | $6.00–$14.00 | Implementation, code review, debugging, routine development |
| **premium** | $2.50–$6.00 | $15.00–$25.00 | Architecture, complex reasoning, security audit, multi-step analysis |
| **max** | $30.00 | $150.00 | Critical security, regulated compliance, last-resort escalation only |

## Model Naming Conventions

Cursor model IDs follow a structured pattern: `{provider-model}[-{reasoning}][-{modifier}]`

| Suffix | Meaning | Cost Impact |
|---|---|---|
| `-none` | No extended thinking | Cheapest for that base model |
| `-low` | Low reasoning effort | Below inherit |
| *(no suffix)* or `-medium` | inherit / medium reasoning | Baseline |
| `-high` | High reasoning effort | Above inherit |
| `-xhigh` | Extra-high reasoning effort | Most expensive for that base model |
| `-fast` | Speed-optimized variant (lower latency, may cost more) | Varies |
| `-thinking-fast` | Extended thinking + speed optimization | Premium |
| `-1m` | Extended context window (1M tokens) | Higher per-token rate |

For any base model, you can trade cost for reasoning quality by adjusting the reasoning suffix. The `-fast` variants trade cost for latency.

## Programmatic Model Registry

Exact IDs for Cursor agent frontmatter and the Task tool. Organized by provider.

### Cursor Native

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `composer-2` | Composer 2 | inherit | no | $0.50 / $2.50 | economy |
| `composer-2-fast` | Composer 2 | inherit | yes | $1.50 / $7.50 | economy |
| `composer-1.5` | Composer 1.5 | inherit | no | $3.50 / $17.50 | standard |

### Anthropic — Claude 4.6

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `claude-4.6-sonnet-medium` | Claude 4.6 Sonnet | medium | no | $3.00 / $15.00 | premium |
| `claude-4.6-opus-high` | Claude 4.6 Opus | high | no | $5.00 / $25.00 | premium |
| `claude-4.6-opus-max` | Claude 4.6 Opus | max | no | $5.00 / $25.00 | premium |
| `claude-4.6-opus-high-thinking-fast` | Claude 4.6 Opus | high+thinking | yes | $30.00 / $150.00 | max |
| `claude-4.6-opus-max-thinking-fast` | Claude 4.6 Opus | max+thinking | yes | $30.00 / $150.00 | max |

### Anthropic — Claude 4.5

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `claude-4.5-haiku` | Claude 4.5 Haiku | inherit | no | $1.00 / $5.00 | economy |
| `claude-4.5-sonnet` | Claude 4.5 Sonnet | inherit | no | $3.00 / $15.00 | standard |
| `claude-4.5-opus-high` | Claude 4.5 Opus | high | no | $5.00 / $25.00 | premium |

### Anthropic — Claude 4

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `claude-4-sonnet` | Claude 4 Sonnet | inherit | no | $3.00 / $15.00 | standard |
| `claude-4-sonnet-1m` | Claude 4 Sonnet | inherit (1M ctx) | no | $6.00 / $22.50 | premium |

### OpenAI — GPT-5.4

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.4-low` | GPT-5.4 | low | no | $2.50 / $15.00 | standard |
| `gpt-5.4-medium` | GPT-5.4 | medium | no | $2.50 / $15.00 | standard |
| `gpt-5.4-medium-fast` | GPT-5.4 | medium | yes | $2.50 / $15.00 | standard |
| `gpt-5.4-high` | GPT-5.4 | high | no | $2.50 / $15.00 | premium |
| `gpt-5.4-high-fast` | GPT-5.4 | high | yes | $2.50 / $15.00 | premium |
| `gpt-5.4-xhigh` | GPT-5.4 | xhigh | no | $2.50 / $15.00 | premium |
| `gpt-5.4-xhigh-fast` | GPT-5.4 | xhigh | yes | $2.50 / $15.00 | premium |

### OpenAI — GPT-5.4 Mini

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.4-mini-none` | GPT-5.4 Mini | none | no | $0.75 / $4.50 | economy |
| `gpt-5.4-mini-low` | GPT-5.4 Mini | low | no | $0.75 / $4.50 | economy |
| `gpt-5.4-mini-medium` | GPT-5.4 Mini | medium | no | $0.75 / $4.50 | economy |
| `gpt-5.4-mini-high` | GPT-5.4 Mini | high | no | $0.75 / $4.50 | standard |
| `gpt-5.4-mini-xhigh` | GPT-5.4 Mini | xhigh | no | $0.75 / $4.50 | standard |

### OpenAI — GPT-5.4 Nano

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.4-nano-none` | GPT-5.4 Nano | none | no | $0.20 / $1.25 | nano |
| `gpt-5.4-nano-low` | GPT-5.4 Nano | low | no | $0.20 / $1.25 | nano |
| `gpt-5.4-nano-medium` | GPT-5.4 Nano | medium | no | $0.20 / $1.25 | nano |
| `gpt-5.4-nano-high` | GPT-5.4 Nano | high | no | $0.20 / $1.25 | economy |
| `gpt-5.4-nano-xhigh` | GPT-5.4 Nano | xhigh | no | $0.20 / $1.25 | economy |

### OpenAI — GPT-5.3 Codex

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.3-codex-low` | GPT-5.3 Codex | low | no | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-low-fast` | GPT-5.3 Codex | low | yes | $1.75 / $14.00 | standard |
| `gpt-5.3-codex` | GPT-5.3 Codex | inherit | no | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-fast` | GPT-5.3 Codex | inherit | yes | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-high` | GPT-5.3 Codex | high | no | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-high-fast` | GPT-5.3 Codex | high | yes | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-xhigh` | GPT-5.3 Codex | xhigh | no | $1.75 / $14.00 | premium |
| `gpt-5.3-codex-xhigh-fast` | GPT-5.3 Codex | xhigh | yes | $1.75 / $14.00 | premium |

### OpenAI — GPT-5.3 Codex Spark (Preview)

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.3-codex-spark-preview-low` | GPT-5.3 Codex Spark | low | no | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-spark-preview` | GPT-5.3 Codex Spark | inherit | no | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-spark-preview-high` | GPT-5.3 Codex Spark | high | no | $1.75 / $14.00 | standard |
| `gpt-5.3-codex-spark-preview-xhigh` | GPT-5.3 Codex Spark | xhigh | no | $1.75 / $14.00 | premium |

### OpenAI — GPT-5.2

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.2-low` | GPT-5.2 | low | no | $1.75 / $14.00 | standard |
| `gpt-5.2-low-fast` | GPT-5.2 | low | yes | $1.75 / $14.00 | standard |
| `gpt-5.2` | GPT-5.2 | inherit | no | $1.75 / $14.00 | standard |
| `gpt-5.2-fast` | GPT-5.2 | inherit | yes | $1.75 / $14.00 | standard |
| `gpt-5.2-high` | GPT-5.2 | high | no | $1.75 / $14.00 | standard |
| `gpt-5.2-high-fast` | GPT-5.2 | high | yes | $1.75 / $14.00 | standard |
| `gpt-5.2-xhigh` | GPT-5.2 | xhigh | no | $1.75 / $14.00 | premium |
| `gpt-5.2-xhigh-fast` | GPT-5.2 | xhigh | yes | $1.75 / $14.00 | premium |

### OpenAI — GPT-5.2 Codex

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.2-codex-low` | GPT-5.2 Codex | low | no | $1.75 / $14.00 | standard |
| `gpt-5.2-codex-low-fast` | GPT-5.2 Codex | low | yes | $1.75 / $14.00 | standard |
| `gpt-5.2-codex` | GPT-5.2 Codex | inherit | no | $1.75 / $14.00 | standard |
| `gpt-5.2-codex-fast` | GPT-5.2 Codex | inherit | yes | $1.75 / $14.00 | standard |
| `gpt-5.2-codex-high` | GPT-5.2 Codex | high | no | $1.75 / $14.00 | standard |
| `gpt-5.2-codex-high-fast` | GPT-5.2 Codex | high | yes | $1.75 / $14.00 | standard |
| `gpt-5.2-codex-xhigh` | GPT-5.2 Codex | xhigh | no | $1.75 / $14.00 | premium |
| `gpt-5.2-codex-xhigh-fast` | GPT-5.2 Codex | xhigh | yes | $1.75 / $14.00 | premium |

### OpenAI — GPT-5.1

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.1-low` | GPT-5.1 | low | no | $1.25 / $10.00 | standard |
| `gpt-5.1` | GPT-5.1 | inherit | no | $1.25 / $10.00 | standard |
| `gpt-5.1-high` | GPT-5.1 | high | no | $1.25 / $10.00 | standard |

### OpenAI — GPT-5.1 Codex Max

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.1-codex-max-low` | GPT-5.1 Codex Max | low | no | $1.25 / $10.00 | standard |
| `gpt-5.1-codex-max-low-fast` | GPT-5.1 Codex Max | low | yes | $1.25 / $10.00 | standard |
| `gpt-5.1-codex-max-medium` | GPT-5.1 Codex Max | medium | no | $1.25 / $10.00 | standard |
| `gpt-5.1-codex-max-medium-fast` | GPT-5.1 Codex Max | medium | yes | $1.25 / $10.00 | standard |
| `gpt-5.1-codex-max-high` | GPT-5.1 Codex Max | high | no | $1.25 / $10.00 | standard |
| `gpt-5.1-codex-max-high-fast` | GPT-5.1 Codex Max | high | yes | $1.25 / $10.00 | standard |
| `gpt-5.1-codex-max-xhigh` | GPT-5.1 Codex Max | xhigh | no | $1.25 / $10.00 | premium |
| `gpt-5.1-codex-max-xhigh-fast` | GPT-5.1 Codex Max | xhigh | yes | $1.25 / $10.00 | premium |

### OpenAI — GPT-5.1 Codex Mini

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5.1-codex-mini-low` | GPT-5.1 Codex Mini | low | no | $0.25 / $2.00 | nano |
| `gpt-5.1-codex-mini` | GPT-5.1 Codex Mini | inherit | no | $0.25 / $2.00 | economy |
| `gpt-5.1-codex-mini-high` | GPT-5.1 Codex Mini | high | no | $0.25 / $2.00 | economy |

### OpenAI — GPT-5

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gpt-5-mini` | GPT-5 Mini | inherit | no | $0.25 / $2.00 | economy |

### Google

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `gemini-3.1-pro` | Gemini 3.1 Pro | inherit | no | $2.00 / $12.00 | standard |
| `gemini-3-flash` | Gemini 3 Flash | inherit | no | $0.50 / $3.00 | economy |
| `gemini-2.5-flash` | Gemini 2.5 Flash | inherit | no | $0.30 / $2.50 | nano |

### xAI

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `grok-4-20` | Grok 4.20 | inherit | no | $2.00 / $6.00 | standard |

### Moonshot

| Programmatic ID | Base Model | Reasoning | Fast | Price (in/out per 1M) | Tier |
|---|---|---|---|---|---|
| `kimi-k2.5` | Kimi K2.5 | inherit | no | $0.60 / $3.00 | economy |

### Special Modes

| Mode | Pricing (per 1M tokens) | Pool | Description |
|---|---|---|---|
| Auto | $1.25 in / $6.00 out / $0.25 cache | Auto+Composer | Cursor selects model dynamically |
| Composer 2 | $0.50 in / $2.50 out / $0.20 cache | Auto+Composer | Cursor's own agentic model |
| Max Mode | +20% on API rate (individual plans) | API | Extended context window to model maximum |

## Pricing by Tier Summary

| Tier | Input per 1M | Output per 1M | Representative Models |
|---|---|---|---|
| **nano** | $0.20–$0.30 | $1.25–$2.50 | `gpt-5.4-nano-*`, `gemini-2.5-flash`, `gpt-5.1-codex-mini-low` |
| **economy** | $0.50–$1.00 | $2.50–$5.00 | `composer-2`, `claude-4.5-haiku`, `gpt-5.4-mini-*`, `gemini-3-flash`, `kimi-k2.5`, `gpt-5-mini` |
| **standard** | $1.25–$2.00 | $6.00–$14.00 | `gpt-5.3-codex-*`, `gpt-5.2-*`, `gpt-5.1-*`, `gemini-3.1-pro`, `grok-4-20`, `claude-4.5-sonnet` |
| **premium** | $2.50–$6.00 | $15.00–$25.00 | `gpt-5.4-high+`, `claude-4.6-sonnet-*`, `claude-4.6-opus-*`, `claude-4.5-opus-*` |
| **max** | $30.00 | $150.00 | `claude-4.6-opus-*-thinking-fast` |

## Agent Model Audit

Current assignments and recommendations based on task complexity analysis.

### Current Assignments

| Agent | Current Model | Effective Tier | Role |
|---|---|---|---|
| `/plan` | inherit | session-dependent | Architecture & spec generation |
| `/dev` | inherit | session-dependent | Code implementation |
| `/sre` | inherit | session-dependent | Infrastructure implementation |
| `/data` | inherit | session-dependent | Data pipeline implementation |
| `/qa` | inherit | session-dependent | QA & security audit |
| `/fix` | inherit | session-dependent | Debugging |
| `/kb` | inherit | session-dependent | Knowledge base generation |
| `security-scanner` | inherit | session-dependent | Security analysis |
| `/run` | composer-2 | economy | Pipeline orchestration |
| `/scrum` | composer-2 | economy | Agile coordination |
| `/summary` | composer-2 | economy | Summary generation |
| `/do` | composer-2 | economy | Ad-hoc operations |
| `codebase-explorer` | composer-2 | economy | Codebase discovery |
| `spec-validator` | composer-2 | economy | Spec compliance checks |
| `dev-reviewer` | composer-2 | economy | Code review |
| `sre-reviewer` | composer-2 | economy | Infra review |
| `data-reviewer` | composer-2 | economy | Data review |
| `plan-reviewer` | composer-2 | economy | Spec review |

### Audit Findings

**Agents appropriately on economy tier (`composer-2` baseline):**
- `codebase-explorer` — Read-only file discovery; economy tier is sufficient
- `spec-validator` — Pattern matching against spec structure; economy tier is sufficient
- `/do` — Ad-hoc operations are typically simple; economy tier is sufficient
- `/run` — Orchestration is coordination, not deep reasoning; economy tier is sufficient
- `/scrum` — Gate decisions use structured scoring; economy tier is sufficient

**Agents that could potentially downgrade:**
- `/summary` — Currently `composer-2`. Appropriate. Summary generation is mostly formatting and extraction, not deep reasoning. Economy tier is sufficient.
- `/kb` — Currently `inherit`. For knowledge base generation, most work is codebase scanning and structured extraction. Could safely use an economy-tier ID for lighter sections. However, understanding architecture patterns benefits from higher reasoning. Keep `inherit` but note as a candidate for evaluation.

**Agents potentially under-resourced on economy tier (`composer-2`):**
- `dev-reviewer` — Code review quality benefits from deeper reasoning, especially for complex logic, concurrency patterns, and security implications. On economy-tier inherits, reviews may miss subtle issues. Consider upgrading to `inherit` or a specific standard-tier model for critical reviews.
- `sre-reviewer` — Infrastructure review involves security, idempotency, and cost analysis. Economy tier may miss nuanced infrastructure concerns. Same consideration as dev-reviewer.
- `data-reviewer` — Data pipeline reviews require understanding schema safety, PII compliance, and migration quality. Economy tier may be insufficient for complex data work. Same consideration as dev-reviewer.
- `security-scanner` — Currently `inherit` (appropriate). Security analysis requires deep reasoning for vulnerability detection. Should remain at `inherit` or a specific premium-tier model. Under-resourcing this agent is a security risk.
- `plan-reviewer` — Spec quality review benefits from deep reasoning to catch completeness and feasibility gaps. On economy tier, reviews may be superficial. Consider upgrading.

**Baseline split:** Implementers and deep-analysis agents use `inherit` (session model); orchestration, reviewers, and scouts use an economy-tier programmatic ID — **`composer-2`** in `.cursor/models.yml` (Cursor’s agent model UI lists programmatic IDs from the catalog, not legacy aliases). Optimization levers:
1. **Session-level model selection** — users choose the session model that `inherit` agents receive
2. **`--model-strategy` flag** — `/run` orchestrator guides model selection per pipeline
3. **Progressive escalation** — retry with higher model before rework

### Recommended Session-Level Model by Workflow

| Workflow | Recommended Tier | Recommended Model | Rationale |
|---|---|---|---|
| Full `/run` pipeline | standard | `gpt-5.3-codex` or `gpt-5.2` | Subagents on economy tier (`composer-2`) already keep costs low; standard is sufficient for `inherit` agents doing implementation |
| `/plan` for complex architecture | premium | `claude-4.6-opus-high` or `gpt-5.4-high` | Architecture decisions need deep reasoning and broad context |
| `/fix` for critical bugs | premium | `claude-4.6-opus-high` | Debugging complex issues benefits from stronger models |
| `/do` quick tasks | economy or Auto | Auto mode or `composer-2` | Simple tasks, cost-sensitive |
| `/dev` for routine implementation | standard | `gpt-5.3-codex` or `claude-4.5-sonnet` | Straightforward coding with clear specs |
| `/qa` security-critical review | premium | `claude-4.6-opus-high` | Security audit requires deep analysis |
| Exploration / onboarding | economy | `claude-4.5-haiku` or `gemini-3-flash` | Read-heavy, low-stakes |
| `/kb` knowledge base build | standard | `gpt-5.2` or `claude-4.5-sonnet` | Balance between extraction quality and cost |

## Progressive Model Escalation

Escalation is tied to the confidence scoring infrastructure (ROAD-13). When a reviewer returns a low confidence score, `/run` considers a model upgrade before triggering a full rework loop.

### Escalation Ladder

```
Step receives reviewer score
  │
  ├─ Score ≥ threshold ──────────────── PROCEED (no escalation)
  │
  ├─ Score 50–74% (ASK_USER zone) ──── Check: was this step run on a lower-tier model?
  │   │
  │   ├─ YES + escalation available ── Retry same step with one-tier-higher model
  │   │                                 (nano→economy, economy→standard, standard→premium)
  │   │                                 Max one escalation per step.
  │   │
  │   └─ NO (already escalated or at premium+) ── Normal ASK_USER / REWORK flow
  │
  └─ Score < 50% (REWORK zone) ──────── Check: was this step run on nano/economy?
      │
      ├─ YES + escalation available ── Escalate model first, then rework if still below
      │
      └─ NO ── Direct rework (model is not the bottleneck)
```

### Rules

1. **Max one escalation per step.** If a step was already escalated and still scores below threshold, proceed to rework — the issue is content, not model capability.
2. **Escalation does not count against `max_review_loops`.** It's a retry with better tooling, not a rework of the content.
3. **Log all escalation events** to the audit log with the format: `MODEL_ESCALATION: {step} | {from_tier} → {to_tier} | {score_before}%`
4. **`--model-strategy` overrides:**
   - `conservative`: Agents start at economy tier regardless of assignment. Escalation is aggressive (triggered at higher thresholds).
   - `balanced` (inherit): Use current model assignments. Escalate only when score is below threshold.
   - `quality`: Agents start at premium tier. No escalation needed — if scores are low, proceed directly to rework.

## Auto & Composer Mode Evaluation

### Cursor Auto Mode ($1.25 in / $6.00 out)

Auto mode lets Cursor dynamically select the model per request. Findings:

**Suitable for:**
- `/do` (ad-hoc tasks) — Auto's dynamic selection matches the variable complexity of ad-hoc work
- `codebase-explorer` — Read-only exploration where model selection is low-stakes
- `/summary` — Structured extraction and formatting where Auto's economy-range cost is appropriate

**Not recommended for:**
- `/plan`, `/qa`, `security-scanner` — These require consistently strong reasoning. Auto's model selection is opaque and may under-resource critical thinking steps.
- `/dev`, `/sre`, `/data` — Implementation quality depends on reliable model capability. Explicit selection gives more control.
- `/run` — Already on economy tier (`composer-2`); orchestration doesn't benefit from Auto's dynamic selection.

**Key concern:** Auto mode selections are not logged or inspectable. For pipeline auditing, explicit model selection provides better traceability. Auto is best used for interactive, non-pipeline work where cost matters more than auditability.

### Composer 2 ($0.50 in / $2.50 out)

Composer 2 is Cursor's purpose-built agentic model at economy-tier pricing.

**Suitable for:**
- `/run` (orchestration) — Composer 2 is designed for agentic coordination; it is the workspace inherit economy ID for those agents.
- `/scrum` (gate decisions) — Structured decision-making with clear criteria.
- `/summary` — Template-driven output generation.

**Not recommended for:**
- Agents requiring deep domain reasoning (`/plan`, `/dev`, `/qa`) — Composer 2 is optimized for coordination, not deep analysis.
- `security-scanner` — Security analysis requires specialized reasoning.

**Recommendation:** `composer-2` is pinned in `models.yml` for orchestration and review agents so assignments match Cursor’s dropdown (programmatic IDs only — do not use non-listed aliases in frontmatter).

### Final Recommendations

The `inherit` / economy-tier split remains the right baseline:

- **Economy-tier agents** (reviewers, orchestrators, validators) — use a catalog ID such as **`composer-2`** for work where cost matters more than maximum depth
- **`inherit` agents** (implementers, architects, debuggers) — quality-sensitive work where the user's session model determines capability

Agent frontmatter also accepts `inherit` and **specific model IDs** (e.g., `model: gpt-5.3-codex`), which enables ROAD-28's dynamic model selection when **`use_manual_models`** is false: `/run` sets per-agent models via `apply-models.sh` before each delegation, then restores baselines from a session snapshot (`--snapshot` / `--restore-agent`). **With manual mode on** (`.cursor/models.user.yml`), `/run` skips those per-step swaps so your table is authoritative. **Optimization should happen dynamically per-run through the `/run` orchestrator** when not in manual mode — not by ad-hoc frontmatter edits mid-pipeline. The adaptive escalation mechanism provides the safety net when the initially selected model proves insufficient.
