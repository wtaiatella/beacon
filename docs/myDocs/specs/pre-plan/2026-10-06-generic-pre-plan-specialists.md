# Pre-plan genérico — especialistas de domínio + repro substituindo o wave Avalara-only

**Data:** 2026-10-06 (pontos abertos resolvidos e implementado em 2026-10-07)
**Status:** ✅ implementado na branch `feature/generic-pre-plan-specialists` — ver "O que foi feito" ao final
**Origem:** discussão em sessão, a partir da constatação de que o pre-plan atual (`mcp-glean`,
`mcp-arc`, `mcp-confluence`, `mcp-gitlab`, `mcp-jira`) é majoritariamente Avalara-específico e não
serve a um SDD genérico.
**Sequenciamento:** esta spec deve ser executada **antes** de
[`2026-10-06-eliminate-sessions-ticket-scoped-state.md`](./2026-10-06-eliminate-sessions-ticket-scoped-state.md)
— ver "Por que esta ordem" ao final.

## Problema

O pre-plan hoje assume ferramentas corporativas específicas da Avalara (ARC/AvaTax Release
Central, Glean, Confluence, Jira, GitLab-como-fonte-de-conhecimento). Isso:

- Torna o framework não-genérico — inútil fora desse ambiente específico.
- Não entrega nada de valor **técnico** sobre o código em si — só busca em sistemas externos de
  conhecimento (tickets, wikis, catálogos). Não analisa o repositório onde a mudança vai acontecer.
- Deixa o `/prd` sem embasamento técnico — ele recebe só o texto do ticket + o que foi achado em
  sistemas externos, nunca uma leitura do código existente.

## Decisão

Substituir o wave Avalara-only por **especialistas de domínio que analisam o código do repositório
alvo** (genéricos, sempre disponíveis, sem dependência de MCP), mais um **agente de reprodução**
para tickets de bug. Jira/Confluence/Glean deixam de ser personas fixas e passam a ser **fontes
opcionais plugáveis**, descobertas e habilitadas via `/setup-workspace`. ARC é removido por completo
(Avalara-only, sem equivalente genérico). GitLab MCP **não** é afetado por esta decisão — continua
existindo para seu outro uso (metadados de MR, criação de MR no §9); só deixa de ser fonte de
conhecimento de pre-plan.

### Princípio não-negociável: WHAT antes do HOW

Os especialistas de pre-plan **nunca propõem solução**. Eles entregam **embasamento técnico** —
o que já existe no código, convenções, e (pra tickets de bug) **hipóteses de causa raiz com
evidência**, não "como corrigir". Quem decide a solução continua sendo exclusivamente o
`/spectech`. Isso preserva a separação já estabelecida na skill `prd-discovery`
("Requirements refinement only — never solution architecture").

## Desenho

### Por que agentes separados, não uma skill única

Reaproveita o mecanismo de **wave** que o `pre-plan-triage` já implementa para Glean/ARC/Jira/
Confluence/GitLab — não é um mecanismo novo, é o mesmo, com conteúdo diferente:

- Cada especialista é um **subagente** pequeno, **read-only** (`Read`, `Grep`, `Glob`; `Bash`
  apenas para comandos de inspeção, nunca para alterar estado).
- `pre-plan-triage` decide **quais** especialistas rodam pra cada ticket (um bug de backend não
  aciona o especialista de frontend).
- Cada um escreve **um** brief limitado em `_run/pre-plan/specialists/<dominio>.md` — mesma
  mecânica de hoje (`pre-plan/specialists/{glean,arc,...}.md`), só troca a fonte: análise de
  código local em vez de chamada MCP externa.
- `/setup-workspace` passa a também poder registrar especialistas extras (de time ou projeto) do
  mesmo jeito que hoje registra servidores MCP — tudo cai em `docs/workspace-tools.md`, que o
  `pre-plan-triage` já lê. Isso dá a "pluggabilidade" pedida sem inventar um segundo mecanismo de
  extensão.

Uma skill única carregada dentro de uma persona perderia o paralelismo (Wave, como hoje
Glean+ARC rodam juntos) e a granularidade de "rodar só o que é relevante para este ticket".

### Contrato de saída (igual para todos os especialistas de domínio)

```markdown
## <Domínio> — grounding
- Código relevante (arquivos/módulos + por quê)
- Padrão/convenção já existente nessa área
- [ticket = bug] Hipóteses de causa raiz, ranqueadas por evidência encontrada no código
                 (nunca "como corrigir")
- [ticket = feature] Restrições/convenções que a solução precisa respeitar
- Perguntas abertas para o /prd resolver com o usuário
```

### Roster proposto

| Agente | Quando o triage aciona | Foco |
|---|---|---|
| **system-design** | quase sempre | Onde a mudança se encaixa na arquitetura atual: módulos/serviços envolvidos, padrões já usados para algo parecido, limites/contratos afetados. Para bug: "esse sintoma tem cheiro de camada X, não de lógica de negócio" |
| **database** | ticket toca persistência | Tabelas/models envolvidos, histórico de migrations da área, integridade/constraints, se o sintoma pode ser formato-de-dado (campo nulo, cache velho, race em escrita) |
| **frontend** | ticket toca UI | Framework/lib de estado em uso, convenções de componente, acessibilidade/compat relevantes ao sintoma |
| **security** | cruza fronteira de auth/input/dados sensíveis | Superfície de ameaça da área, como endpoints parecidos já validam input — alimenta o spec desde o início em vez de só pegar isso depois no `security-scanner` do QA |
| **testing/observability** (extra sugerido) | sempre, leve | O que já existe de teste/log/métrica para essa área — "não há log aqui" costuma ser a própria causa raiz de "não sabemos por que falha", e é um achado valioso para o `/spectech` incluir na solução |

Lista inicial, extensível via `/setup-workspace` (times/projetos podem registrar especialistas
adicionais específicos do seu domínio, ex. "pagamentos", "compliance fiscal", etc.).

### Agente de reprodução (bug/issue apenas)

Separado dos especialistas de domínio: eles fazem **análise/raciocínio**; este faz **evidência
empírica**. Só é acionado pelo `pre-plan-triage` para tickets de bug/issue.

- Procura **comandos já documentados no próprio repositório** (scripts de `package.json`,
  `Makefile`, `docker-compose`, suíte de teste existente) — nunca improvisa um jeito de subir
  serviço (mesma filosofia Zero-Trust já aplicada ao resto do framework: nenhum comando ad-hoc
  inventado na hora).
- Se achar um caminho viável: escreve um teste/fixture mínimo que reproduz o sintoma e roda,
  capturando stack trace/erro real.
- Se não achar: reporta isso também ("não foi possível reproduzir automaticamente — motivo X"),
  em vez de forçar uma tentativa insegura.
- Saída: evidência de causa raiz. **Nunca** a correção.
- **Reaproveitamento, não duplicação:** `/fix` já tem um workflow "reproduce → isolate → fix →
  verify" para debug ad-hoc fora do pipeline. A parte de **reproduzir** deve ser extraída para uma
  peça reaproveitável que tanto `/fix` (standalone) quanto esta wave de pre-plan (`/run`) chamam —
  em vez de duas implementações da mesma lógica.
- Referência de inspiração (ambiente paralelo `bcs`, específico daquele workspace, **não**
  portável como está): skills `/bcs-repro` e `/bcs-sandbox`. Usar só como inspiração de forma, não
  de conteúdo — este agente deve ser genérico desde o desenho.

### Jira / Confluence / Glean — de personas fixas a fontes opcionais

Continuam existindo como capacidade, mas deixam de ser `mcp-jira.md` / `mcp-confluence.md` /
`mcp-glean.md` sempre presentes no framework. Passam a ser **descobertas e habilitadas** via
`/setup-workspace` (que já pergunta ao usuário quais MCPs/skills adicionais ele quer disponibilizar
ao SDD) e só roteadas pelo `pre-plan-triage` quando: (a) estão configuradas **e** (b) o texto do
ticket dá sinal de referência externa (igual à detecção de pistas que o triage já faz hoje —
"ticket", "Jira", "Confluence", "design doc"). **ARC é removido por completo** — não tem
equivalente genérico. **GitLab MCP não é tocado por esta decisão** — seu uso em §9 (criação de MR)
e leitura de metadados de branch/proteção continua como está; só some como fonte de pre-plan.

### Fluxo final ("escaneia uma vez, reaproveita em todo lugar")

```
codebase-explorer (orientação geral — só se o diretório for desconhecido)
   → especialistas de domínio (grounding; root-cause se bug, restrições se feature)
   → [se bug] agente de reprodução (evidência empírica, lógica compartilhada com /fix)
   → [opcional, se configurado + sinal no ticket] Jira/Confluence/Glean
   → merge em _run/pre-plan/
   → /prd (prd-discovery só pergunta escopo/requisito — informado pelo grounding, nunca decide solução)
   → /spectech (spectech-analyzer REAPROVEITA os mesmos briefs em vez de re-escanear o código do zero — aqui sim decide o HOW)
   → /tasks
```

### Papel de cada peça (evitando sobreposição)

| Peça | Papel | O que NÃO faz |
|---|---|---|
| `pre-plan-triage` | Roteia quais especialistas (domínio + repro + enterprise opcional) entram na wave para este ticket | Não analisa nada ele mesmo |
| `codebase-explorer` | Orientação estrutural genérica ("onde fica o quê") quando o diretório é desconhecido | Não traz julgamento de domínio |
| Especialistas de domínio (novo) | Grounding técnico + causa raiz (bug) / restrições (feature) | Nunca propõe solução; reaproveita o output do `codebase-explorer` se já rodou, em vez de re-escanear |
| Agente de reprodução (novo) | Evidência empírica de causa raiz, só bug | Nunca propõe correção |
| `prd-discovery` | Clarifica requisito/escopo (WHAT) com o usuário, agora informado pelo grounding | Nunca decide arquitetura/solução |
| `spectech-analyzer` | Decide a solução (HOW), reaproveitando os briefs do pre-plan | Para de re-escanear o código do zero |

## Escopo da migração

| Item | Ação |
|---|---|
| `agentic/agents/mcp-arc.md` | remover |
| `agentic/agents/mcp-glean.md`, `mcp-confluence.md`, `mcp-gitlab.md` (como fonte de pre-plan), `mcp-jira.md` | reclassificar como opcionais, habilitados via `/setup-workspace`; `mcp-gitlab.md` mantém seu outro papel (§9) intacto |
| Novos agentes | `system-design-specialist.md`, `database-specialist.md`, `frontend-specialist.md`, `security-specialist.md`, `testing-observability-specialist.md` (sugestão extra), `repro-specialist.md` |
| `agentic/agents/pre-plan-triage.md` | reescrever regras de roteamento: especialistas de domínio sempre candidatos (sem depender de MCP); enterprise (Jira/Confluence/Glean) só se registrado em `docs/workspace-tools.md` **e** sinal no ticket; ARC removido |
| `agentic/skills/setup-workspace/SKILL.md` | estender para também perguntar/registrar especialistas de domínio adicionais (não só MCPs) |
| `/fix` (`agentic/agents/fix.md`) | extrair o passo "reproduce" para peça compartilhada com `repro-specialist` |
| `agentic/agents/prd.md` / skill `prd-discovery` | consumir o brief de grounding como contexto adicional, sem mudar sua natureza WHAT-only |
| `agentic/agents/spectech.md` / skill `spectech-analyzer` | reaproveitar os briefs do pre-plan em vez de re-escanear o código |
| `agentic/skills/run-pipeline/SKILL.md` | reescrever a seção "Pre-plan context (optional MCP)" — novo wave de especialistas de domínio + repro, Jira/Confluence/Glean como opcionais, ARC removido |
| `CLAUDE.md` / `README.md` | atualizar menções a ARC/Glean/Confluence/Jira/GitLab como pre-plan obrigatório |

## Por que esta ordem (antes da migração de sessions)

A reforma do pre-plan **apaga/substitui** vários `agentic/agents/mcp-*.md` que a migração de
sessions ([spec irmã](./2026-10-06-eliminate-sessions-ticket-scoped-state.md)) teria que tocar só
para trocar caminho `docs/sessions/...` → `_run/...`. Fazendo esta spec primeiro:

1. Os agentes novos (especialistas + repro) já nascem escrevendo direto em
   `_run/pre-plan/specialists/...` — o layout final já desenhado na spec de sessions — sem
   precisar migrar depois.
2. A migração de sessions, quando vier, lida com um conjunto de agentes menor e estável (os
   `mcp-*.md` obsoletos já terão sumido ou sido reclassificados).

## Abertos — resolvidos em 2026-10-07

- **Modelo de cada especialista:** tratado separadamente — ver
  [`2026-10-07-per-install-model-config.md`](./2026-10-07-per-install-model-config.md). Com esse
  desenho, todo agente (incluindo os especialistas novos) nasce `inherit` por padrão; quem quiser
  um tier diferente por especialista configura no arquivo local por instalação, não no frontmatter
  canônico.
- **`testing/observability` entra na v1 — com escopo explicitamente diferente do QA:**
  - **Pre-plan (`testing/observability` specialist, novo):** visão de **gap** — o que falta
    (teste/log/métrica inexistente nessa área) para que `/prd` registre como requisito e
    `/spectech` projete a cobertura/observabilidade junto da solução. Alimenta o PRD/Spectech,
    nunca verifica nada.
  - **QA (já existente — `spec-validator`/`dev-reviewer`/`/qa`):** visão de **verificação** — o
    código implementado está coberto pelos testes previstos e os testes estão passando. Continua
    exatamente como hoje, sem mudança.
  - São duas visões complementares, não a mesma peça duplicada: uma pergunta "o que falta
    planejar", a outra "o que foi entregue está correto".
- **Formato de `docs/workspace-tools.md`:** doc único (não ler skill por skill) — uma entrada por
  ferramenta/especialista com: nome, como invocar, parâmetros (se houver), descrição do retorno /
  quando usar. Coletado no momento em que `/setup-workspace` roda (mesma mecânica que já produz
  esse arquivo hoje para MCPs — só estende o schema pra também cobrir especialistas de domínio).
- **Gatilho do `repro-specialist`:**
  - **Bug/issue:** sempre tenta.
  - **Feature / outra modificação:** fica a critério do próprio agente decidir se a simulação
    agrega para estabelecer causa raiz / estado atual de funcionamento / comportamento esperado ao
    final — não é um gate fixo do triage, é julgamento do agente caso a caso.

## O que foi feito (2026-10-07)

- **6 agentes novos**, todos `model: inherit`, seguindo o contrato de saída da spec:
  `system-design-specialist.md`, `database-specialist.md`, `frontend-specialist.md`,
  `security-specialist.md`, `testing-observability-specialist.md`, `repro-specialist.md`.
- **Skill nova `agentic/skills/repro/SKILL.md`** — procedimento compartilhado entre `/fix` e
  `repro-specialist` (nunca improvisa comando de subir serviço; só usa o que o repo já documenta).
- **`mcp-arc.md` removido.** `mcp-glean.md`, `mcp-confluence.md`, `mcp-jira.md` reclassificados
  como opcionais/opt-in (texto de Role explicando o gate). `mcp-gitlab.md` ajustado pra deixar
  claro que não é mais fonte de pre-plan (mantém seu papel em §9/branch-gate).
- **`pre-plan-triage.md` reescrito**: `ticket_type` (bug/feature/other), `domain_specialists`
  (sempre candidatos, sem MCP), `repro_candidate` (bug sempre; feature/other = julgamento do
  agente), `wave2_sources` (Jira/Confluence/Glean só com registro em `docs/workspace-tools.md` **e**
  sinal no ticket — os dois gates).
- **`run-pipeline/SKILL.md`** — seção "Pre-plan context" reescrita (novo nome: "domain specialists
  + optional MCP"), todas as 7 referências cruzadas a ARC/wave1/wave2 no arquivo corrigidas.
- **`/fix`** — passo "Reproduce" agora referencia a skill `repro` compartilhada.
- **`/prd`** — passo "Scan for context" passa a ler o `Pre-plan context:` como embasamento técnico
  (nunca solução); guardrail novo reforçando isso.
- **`/spectech` + `spectech-analyzer`** — reaproveitam os briefs de pre-plan antes de re-escanear o
  código do zero.
- **`setup-workspace`** — novo `--specialist <name>` pra registrar especialistas de domínio
  customizados (schema `## specialist: <name>` em `docs/workspace-tools.md`, distinto do schema de
  MCP server).
- **`scripts/hooks/pipeline-init.sh`** — checagem `arc-declared-in-mcp-json` removida (ARC não
  existe mais como conceito do framework); warning de Knowledge Base simplificado pra só checar KB
  local.
- **`AGENTS.md`/`CLAUDE.md`/`README.md`** — todas as menções a ARC/wave1/wave2 Avalara-specific
  atualizadas (Supporting Subagents, Knowledge Base, diagramas mermaid, MCP configuration).
- Testado: reinstalação via `setup-agentic.sh claude` e `cursor` confirma os 6 agentes novos
  instalados, `mcp-arc.md` corretamente removido/prunado (incluindo prune automático do lado
  Cursor), skill `repro` instalada, tudo com `model: inherit`.
- Implementado na branch `feature/generic-pre-plan-specialists` (a partir de `convert-to-cursor`).

### Deixado de fora (pré-existente, fora do escopo desta spec)

- `scripts/tools/verify-preplan-orchestration-docs.sh` (rodado no CI) e
  `verify-mcp-arc-orchestration-docs.sh` / `verify-domain-persona-parity.sh` (não rodam no CI)
  ainda apontam pra caminhos antigos (`.cursor/skills/...`, `.cursor/rules/...` como se fossem
  fonte canônica) e ainda esperam `Task(mcp-arc)` em alguns asserts — já estavam quebrados antes
  desta spec (layout pré-refatoração `agentic/`), não corrigidos aqui.
- `docs/run-pipeline-reference.md` e `CONTRIBUTING.md` continuam com staleness mais ampla já
  identificada em sessões anteriores (não é escopo desta spec).
- `docs/reference/arc-mcp-workflow.md` e `docs/arc-onboarding.md` ficaram como docs de referência
  órfãos (não deletados) — nenhum agente ativo os referencia mais.

## Adendo (2026-10-08) — gate de crítica do pre-plan (`pre-plan-reviewer`)

**Origem:** experiência real do usuário em dois contextos (ticket de trabalho + projeto pessoal) —
descoberta de causa raiz e embasamento de contexto raramente ficam bons na primeira tentativa. O
fluxo manual que já funciona: Agente A escreve o contexto → Agente B critica (gaps/inconsistência/
ambiguidade) → a crítica volta pro Agente A, que confronta e corrige. Relato: **100% das vezes**
o segundo agente encontra algo. Esse padrão já existe no framework (self-heal do §4,
`plan-reviewer` + `scrum`, sobre `prd.md`+`spectech.md`+`tasks.md`) — mas faltava **uma etapa
antes**, sobre o merge dos especialistas de pre-plan, que é exatamente onde a dor do usuário está.

**Mecanismo (esclarecimento):** não é "deixar o chat do agente A aberto" — subagentes do Claude
Code não compartilham memória entre chamadas de `Task(...)`. O padrão real (já usado no §4 e agora
replicado aqui) é **persistir em disco + re-alimentar via prompt condensado**: o agente critica o
artefato já escrito no disco; a crítica (condensada, não a íntegra) é injetada no próximo
`Task(<especialista>)`, que relê o artefato e decide se concorda.

### Decisão

Novo agente **`pre-plan-reviewer`** (read-only, `model: inherit`) — roda **depois do merge, antes
do `Task(prd)`**. Mesma forma do `plan-reviewer`: produz score + `Findings` + `Verdict`, mas com um
requisito extra: **toda finding precisa nomear qual especialista deve ser reexecutado** (nunca "a
wave inteira de novo"). `Task(scrum)` ganha um **4º gate** (pre-plan gate) decidindo PROCEED/
REWORK/ASK_USER/ESCALATE, com a mesma autoridade dos outros 3 gates já existentes.

```
pre-plan wave (especialistas + repro + opcional) → merge (merged-brief.md)
   → Task(pre-plan-reviewer) [critica: causa-raiz clara? consistente? completo? ambíguo?]
   → Task(scrum) [gate]
       REWORK → reexecuta SÓ o(s) especialista(s) nomeado(s) (+ "triage gap" se aplicável)
                → re-merge → re-review (loop, teto --max-preplan-iterations, default 3)
       PROCEED/ASK_USER → Task(prd)
```

### O que foi feito

- **`agentic/agents/pre-plan-reviewer.md`** (novo) — 5 fatores de confiança (clareza de causa
  raiz, consistência interna, completude vs. superfície do ticket, ambiguidade/acionabilidade pro
  `/prd`, qualidade do repro), sempre atribuindo a finding a um especialista nomeado.
- **`agentic/skills/run-pipeline/SKILL.md`** — novo step 6 ("Pre-plan review gate") entre o merge
  (step 5) e `Task(prd)` (renumerado para step 7); nova flag `--max-preplan-iterations` (default 3,
  independente de `--max-plan-iterations`).
- **`agentic/agents/scrum.md`** — 4º gate (`## Pre-plan gate`), descrição/frontmatter atualizados
  de "Two injection modes" pra "Four", parágrafo de autorização no mesmo padrão dos outros 3.
- **`agentic/AGENTS.md`** — `pre-plan-reviewer` na tabela de Reviewers, flag nova documentada.

### Observação de design

Esse gate **não** toca `_state.json`/`_notes.md` (não existe spec ainda nesse ponto) — a primeira
escrita de controle continua sendo depois do gate do §4 (plan segment), como já era.

## Adendo (2026-10-08) — execução por etapas (`--pre-plan` / `--plan` / `--dev` / `--finish`)

**Origem:** mesma conversa do gate de crítica — o usuário quer poder parar o `/run` em pontos de
checkpoint específicos (pra revisar/aprovar manualmente entre etapas, inclusive em invocações
separadas, possivelmente em dias diferentes). Cross-cutting: não é só pre-plan, toca os limites de
§4 e §6 também — registrado aqui por ter surgido na mesma conversa, mas é uma feature própria do
`run-pipeline`, não do pre-plan especificamente.

### Decisão

4 flags **mutuamente exclusivas**, cada uma um **checkpoint** (não um executor isolado — roda tudo
normalmente até o fim daquela etapa, então para):

| Flag | Para depois de | Mensagem final |
|---|---|---|
| `--pre-plan` | Gate de crítica do pre-plan (`pre-plan-reviewer` + `scrum`) — antes do `Task(prd)` | `STAGE COMPLETE: pre-plan` |
| `--plan` | Gate do §4 (`scrum` PROCEED em prd/spectech/tasks) — antes do §5 | `STAGE COMPLETE: plan` |
| `--dev` | §6 completo da **última** fase — antes do §7.0 | `STAGE COMPLETE: dev` |
| `--finish` | Conclusão normal (§7.0→§9) | `PIPELINE: COMPLETE` (de novo, sem early-stop) |

**Encadeamento entre invocações separadas:** usa o `--resume` que já existe — sem mecanismo novo de
sessão. Primeira chamada sem `--resume`; todas as seguintes **com** `--resume`:

```
/run docs/specs/{slug}/ --pre-plan
/run docs/specs/{slug}/ --plan   --resume
/run docs/specs/{slug}/ --dev    --resume
/run docs/specs/{slug}/ --finish --resume
```

**Nota de nomenclatura:** `--finish` aqui é mais amplo que o termo "§9 Finish" já usado no skill
(que é só o commit/push/MR) — `--finish` cobre §7.0→§9. Documentado explicitamente pra não
confundir.

### O que foi feito

- **`run-pipeline/SKILL.md`** — nova seção "Staged execution (checkpoint flags)" (semântica
  completa, tabela, mensagens, interação com `--resume`/`--skip`/`--manual`); 3 pontos de parada
  reais conectados no fluxo (fim do gate de pre-plan, fim do §4, fim do §6 da última fase);
  template de saída `STAGE COMPLETE: <name>`; nota em "Invalid completion" pra não confundir parada
  intencional com falha.
- **`AGENTS.md`/`README.md`** — flags novas documentadas nas tabelas de flags.

### Observações / limitação conhecida

- Essas flags **assumem** que, se usadas em invocações separadas, o usuário sempre lembra de
  passar `--resume` depois da primeira. Nenhuma validação automática impede esquecer isso hoje —
  esquecer gera uma sessão nova (comportamento padrão do `--resume` ausente), não um erro.
- Quando a migração de sessions ([spec irmã](./2026-10-06-eliminate-sessions-ticket-scoped-state.md))
  acontecer, esse encadeamento fica mais robusto por natureza (estado por ticket, não por sessão
  rotativa) — vale revisitar esta seção depois dessa migração.
