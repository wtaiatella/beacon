# Análise do fluxo SDD do repositório (`/run`)

> Fontes analisadas: `CLAUDE.md` (raiz), `README.md` e `agentic/skills/run-pipeline/SKILL.md` (fonte canônica do orquestrador).
> Diagrama: `myDocs/sdd-pipeline-flowchart.excalidraw` (editável) / `myDocs/sdd-pipeline-flowchart.png` (preview).

## Visão geral

Não existe um agente `/run` de fato — o **loop de conversação principal (main session)** é o
orquestrador e delega tudo via `Task(...)` para subagentes de persona e helpers read-only.
Subagentes **nunca** chamam `Task()` entre si (orquestração *flat* — é uma limitação real do
runtime do Claude Code, não só uma convenção). Quando uma persona precisa de algo fora do seu
escopo (MCP corporativo, decisão humana, outro helper), ela devolve uma linha de escalonamento
(`REQUEST_MAIN:`, `QUESTION:`/`ASK_USER`, `APPROVAL_NEEDED:`) e é o main loop que decide o que
fazer a seguir.

## As 9 seções do pipeline (`run-pipeline` SKILL.md)

| # | Seção | O que faz | Quem executa |
|---|-------|-----------|---------------|
| 1 | Preconditions | **Informativo, não é gate duro.** Detecta a branch atual; se não for a protegida/padrão, pergunta se quer trocar só para a análise ou continuar assim. Não bloqueia Init nem `/prd`/`/spectech`/`/tasks` — esses só escrevem na ticket folder (`docs/specs/`, gitignored), sem risco | Main loop (scripts) |
| 2 | Init | Roda `pipeline-init.sh`: cria sessão em `docs/sessions/<id>/`, snapshot de modelos, lê session memory, avisa se falta KB | Main loop |
| — | Pre-plan context (opcional) | `Task(pre-plan-triage)` decide quais MCPs valem a pena → Wave 1 (Glean/ARC, paralelo) → merge+gate → Wave 2 (Jira/Confluence/GitLab, só se necessário) → `merged-brief.md` | `Task(mcp-*)` |
| 3–4 | PRD → Spectech → Tasks | `Task(prd)` → `Task(spectech)` → `Task(tasks)`, sempre nessa ordem fixa (nunca existiu `/plan` de arquivo único neste repo) | Personas de front-end |
| 4 | Plan-review self-heal | `Task(plan-reviewer)` em **modo pasta** (revisa os 3 artefatos de uma vez) → `Task(scrum)` decide PROCEED/ASK_USER/REWORK/ESCALATE. REWORK reexecuta **só** a persona apontada, nunca as 3 — até `--max-plan-iterations` (padrão 3) | `plan-reviewer`, `scrum` |
| 5 pre-check | **Gate duro de branch** (1x por run) | Só aqui — imediatamente antes do primeiro `Task(dev\|sre\|data)` — é que o pipeline escreve de fato no repo de trabalho. Branch protegida? para e pergunta: abortar / ficar na atual / criar nova (nome aprovado pelo usuário). Padrão **sem `git worktree`** — checkout direto na branch resolvida; worktree só se o usuário pedir isolamento explicitamente. O hook `subagent-gate` é um 2º backstop independente (bloqueia `Write`/`Edit` em branch protegida de qualquer forma) | Main loop (scripts) |
| 5 | Implementation | Por **fase** (`### Phase N`), `Task(dev)`/`Task(sre)`/`Task(data)` em paralelo quando a fase permite múltiplos domínios. Nunca uma `Task` cobre 2 fases | `dev`, `sre`, `data` |
| 6 | Implementation review | Reviewers de domínio em paralelo + `Task(security-scanner)` (escopo `phase-impl-delta`) → `Task(scrum)` da fase. Critical/High = REWORK obrigatório. Depois do PROCEED, `Task(do)` aplica os "Proposed spec updates" (checkboxes + `_state.json`) — a spec nunca é editada à mão pelo orquestrador | `*-reviewer`, `security-scanner`, `scrum`, `do` |
| 7.0 | QA prep | `Task(spec-validator)` + `Task(security-scanner)` → `artifacts/scanners/` (obrigatório sempre que `Task(qa)` roda sem `--skip qa`) | `spec-validator`, `security-scanner` |
| 7 | QA | `Task(qa)` — auditoria cross-domain (spec compliance, segurança, AC). Bloqueia merge em achados Critical/High | `qa` |
| 7.1 | Gate pós-QA | `Task(scrum)` final: PROCEED / ASK_USER / REWORK (volta ao domínio) / ESCALATE | `scrum` |
| 8 | Summary | `Task(summary)` escreve `summary.md` (handoff) | `summary` |
| 9 | Finish | `pipeline-finish.sh` — commit com a mensagem escolhida pelo usuário → pergunta explícita de **push** → pergunta explícita de **MR** (via GitLab MCP, mostrando título/corpo antes) | Main loop (scripts + MCP) |

## Regras que não podem ser quebradas (não-negociáveis)

- **Git/GitLab:** só o orquestrador comita/push/cria MR, e só nos pontos autorizados (§9 Finish,
  ou mid-pipeline via `commit_policy` quando o usuário já autorizou). Nunca `git commit`/`push`
  cru fora desses hooks.
- **Branch consent:** nunca cria branch sem o usuário aprovar o nome. Esse gate duro fica no §5
  pre-check (antes do primeiro `Task(dev|sre|data)`) — não no §1. Worktree é opt-in: o padrão é
  trabalhar direto na branch (sem cópias/pastas extras); só cria worktree se o usuário pedir
  isolamento explicitamente.
- **Confidence scoring** (mesmo threshold em todos os gates, salvo override documentado):
  - `>= 75%` → PROCEED
  - `50–74%` → ASK_USER
  - `< 50%` → REWORK automático
  - Limite de loops atingido → ESCALATE
- **Um único control file por ticket:** `_state.json` + `_notes.md` — nunca `context.json`
  (se os dois existirem na mesma pasta, é um bug a ser reportado, não resolvido silenciosamente).
- **Least-privilege de contexto:** cada `Task(...)` só recebe o que a "least-privilege matrix" da
  skill autoriza (ex.: `Task(dev)` nunca recebe o `qa-report.md` nem transcripts de outras personas).

## Pontos de entrada / flags úteis para iterar

- `/run <ticket-folder|JIRA-KEY> [flags]` — pipeline completo, automático por padrão.
- `--skip plan|impl-review|qa|summary` — pula segmentos específicos.
- `--manual` — pausa após o segmento de plano e após cada track de domínio (gate manual).
- `--review` — checkpoints por step (ortogonal ao `--manual`).
- `--resume` — retoma do último `GATE:`/`FAILURE:` registrado na sessão.
- `--max-iterations N` / `--max-plan-iterations N` — tetos de loop de rework.
- Fora do `/run`: `/fix` (bugs), `/do` (tarefas rápidas), `/clone`, `/rebase`, `/kb-refresh`,
  `/kb-concentrator`, `/setup-workspace` — utilitários não plugados ao pipeline.

## Observações para a próxima rodada de melhorias

Pontos que valem discutir ao editar o fluxograma:

1. O gate `--manual` (pausas manuais) não está desenhado no diagrama — hoje o diagrama mostra o
   fluxo **automático** (default). Pode valer adicionar uma variante/anotação para `--manual`.
2. O "Pre-plan context" (MCP opcional, 2 waves) está simplificado no diagrama — na prática tem
   bastante detalhe de roteamento condicional (`pre-plan-triage` decide o que roda).
3. O diagrama não mostra os loops `--resume` (retomar de um `GATE:` específico) nem o fluxo de
   `commit_policy` (per_task/per_phase/end) do §9/mid-pipeline.
4. Projetado para edição: as caixas de "REWORK" à esquerda estão com roteamento em cotovelo
   (elbow) manual — se mover blocos no Excalidraw, as linhas não se re-roteiam automaticamente
   (não estão "bound" aos elementos, ao contrário das setas de fluxo principal).
