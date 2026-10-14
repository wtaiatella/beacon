# Eliminar `docs/sessions/` — estado de execução passa a viver na pasta do ticket

**Data:** 2026-10-06
**Status:** executado em 2026-10-14. O ponto antecedente foi superado pela ordem de executar. Ajustes em relação ao texto original: `session.code-workspace` também fica em `_run/`; o snapshot de modelos vai para `docs/local/.model-snapshot`; `diffs/plan/` entra no layout; o scaffold `artifacts/mcp-briefs/` não é criado.
**Origem:** discussão em sessão — questionamento sobre a necessidade real de `docs/sessions/`
agora que existe a ticket folder (`_state.json`/`_notes.md`) como estado persistente por ticket.

## Problema

`docs/sessions/<timestamp-id>/` é uma camada de estado **global**, indexada por um id de sessão
rotativo (`ACTIVE_SESSION`), criada quando o único lugar pra guardar progresso era um `spec.md`
solto, sem pasta própria. Hoje, com a ticket folder (`docs/specs/{date}-{ticket}-{slug}/` +
`_state.json` + `_notes.md`), essa camada:

- **Duplica dados que já têm dono canônico** — `commit_policy` já vive em
  `_state.json.commit_policy`; a sessão só reescreve isso como linha de log.
- **Perde dados úteis por limpeza automática** — arquivos de sessão não tocados em >24h são
  apagados; isso inclui `pre-plan/merged-brief.md` (o brief de pesquisa que ajudou a escrever o
  PRD), que seria mais útil permanecendo junto do ticket.
- **É menos robusta pro uso real** — o padrão de uso é "um ticket = um chat, quase nunca dois
  tickets simultâneos no mesmo chat." Retomar um ticket no dia seguinte depende hoje de
  `ACTIVE_SESSION` ainda apontar pro id certo (pode ter rotacionado por outro `/run` no meio).
  Se o estado morar dentro da própria pasta do ticket, "retomar" é só "ler aquela pasta" — sem
  indireção, sem id pra perder.
- **Inconsistência já existente:** `qa-report.md` (QA final) já é escrito direto na ticket folder;
  os artefatos de QA-prep (`spec-validator.md`, `security-scanner.md`) que o alimentam ficam na
  sessão. Hoje já está dividido entre os dois sistemas sem motivo claro.

## Decisão proposta

Eliminar `docs/sessions/` por completo. Todo estado de execução de um `/run` passa a viver dentro
da própria pasta do ticket, numa subpasta `_run/` (convenção com prefixo `_` igual a `_state.json`
e `_notes.md` — "do framework, não é conteúdo do ticket"; evita colidir com o termo já reservado
"control file" = `_state.json`/`_notes.md`).

### Novo layout

```
docs/specs/{YYYY-MM-DD}-{TICKET-KEY}-{slug}/
├── _state.json            # inalterado — machine state (steps, commit_policy, ...)
├── _notes.md              # inalterado — log humano / decisões
├── ticket.md
├── attachments/
├── prd.md
├── spectech.md
├── tasks.md
├── qa-report.md
├── summary.md
└── _run/                   # NOVO — substitui docs/sessions/<id>/ por completo
    ├── timeline.md          # era current.md: GATE:/DECISION:/QUESTION:/impl + trace anchors
    ├── audit.log            # era context-audit.log (saida do Finish)
    ├── attach-target.txt    # era docs/sessions/<id>/attach-target.txt (multi-root)
    ├── pre-plan/
    │   ├── merged-brief.md  # era pre-plan/merged-brief.md
    │   └── specialists/     # era pre-plan/specialists/*.md
    ├── explorer/            # era artifacts/explorer/*.md
    ├── scanners/            # era artifacts/scanners/*.md
    └── diffs/{dev,sre,data}/
```

### O que desaparece por completo

| Conceito hoje | Motivo da eliminação |
|---|---|
| `docs/sessions/ACTIVE_SESSION` | identidade passa a ser o caminho da pasta do ticket, já explícito em todo `/run`/`/dev`/etc. |
| Rotação de session-id por timestamp (`begin-run`) | sem pasta global, nada a rotacionar |
| Prune automático >24h | `_run/` vive e morre junto do ticket |
| `.model-snapshot` global (`apply-models.sh`) | **órfão** — mecanismo só do Cursor (Claude Code não troca modelo por step); fica estacionado — ver "Ponto antecedente" |
| `docs/sessions/README.md` | sem propósito sem a pasta |

### `--resume`

Hoje: `ACTIVE_SESSION` → `docs/sessions/<id>/current.md` → última linha `GATE:`.
Novo: pasta do ticket (já passada ao `/run`) → `<ticket>/_run/timeline.md` → última linha `GATE:`.

### `/fix` e `/do` (sem pasta de ticket)

Decisão: **sem estado persistente**. São escape hatches de tarefa rápida / chat único — se
interromper, descreve o sintoma de novo. Nada a migrar aqui.

## Escopo da migração (~50 arquivos referenciam `docs/sessions` hoje)

| Camada | Arquivos | Mudança |
|---|---|---|
| Scripts "motor" | `session-memory.sh` (provável rename, ex. `ticket-run.sh`), `session-handoff.sh`, `apply-models.sh`, `cursor-project-hash.sh`, `audit-session-trace.py`, `query-transcript.py` | passam a receber a **pasta do ticket** como parâmetro em vez de resolver `ACTIVE_SESSION` |
| Hooks | `pipeline-init.sh`, `pipeline-finish.sh`, `pipeline-commit.sh` | trocam `docs/sessions/<id>/...` por `<ticket>/_run/...`; `pipeline-init.sh` não faz mais `begin-run` |
| Skill normativa | `agentic/skills/run-pipeline/SKILL.md` | maior revisão — "Session storage", §2 Init, least-privilege matrix, `--resume` |
| Agentes | ~16 arquivos em `agentic/agents/*.md` | trocar referências de caminho (mecânico) |
| Hook de sessão do IDE | `agentic/hooks/session-init.sh` | hoje injeta "session id ativo"; repensar ou simplificar/remover |
| Docs | `docs/run-pipeline-reference.md`, `agentic/docs/README.md`, `CLAUDE.md`, `README.md` | atualizar |
| Testes | 6 arquivos em `scripts/tools/tests/` | reescrever fixtures que hoje montam `docs/sessions/<fake-id>/` |

### Ordem de execução sugerida

1. Script motor novo (API baseada em `--ticket <pasta>`) — isolado, testável sozinho.
2. Os 3 hooks apontando pro script novo.
3. `run-pipeline/SKILL.md` (reescrita maior).
4. `agentic/agents/*.md` (achar/trocar caminhos).
5. `session-init.sh` hook + docs (`CLAUDE.md`, `README.md`, `run-pipeline-reference.md`) por último.
6. Testes acompanhando cada etapa.

## Pontas relacionadas (fora do escopo desta mudança, registradas aqui pra não perder)

- `.gitignore` ainda comenta que `docs/specs` seria um symlink pra um workspace `bcs` irmão,
  compartilhado entre dois workspaces — resquício do tempo em que isso era compartilhado (mesma
  categoria do `CODEOWNERS` já removido). `docs/specs` nem existe ainda neste repo. Vale limpar
  esse comentário quando formos nessa área.
- `.model-snapshot` / troca de modelo por step é mecanismo só do Cursor, já sem efeito no Claude
  Code — **resolvido em** [`2026-10-07-per-install-model-config.md`](./2026-10-07-per-install-model-config.md)
  (arquivo de config local por instalação, `inherit` por padrão em todo agente).

## Ponto antecedente (a discutir antes de priorizar esta migração)

O usuário levantou, ao revisar a ponta "auditoria" (item 3 das pontas soltas da sessão anterior),
um tema novo: **controle do próprio `beacon` (o framework) vs. controle de execução do SDD em
projetos reais** (os repositórios-alvo onde o trabalho de fato acontece). A suspeita é que resolver
esse tema primeiro pode simplificar ou mudar o desenho desta migração (por exemplo, se parte do
estado de execução precisar diferenciar "rodando dentro do beacon" de "rodando num repo-alvo
anexado via multi-root"). **Ainda não detalhado — próxima conversa.**
