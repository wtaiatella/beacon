# Caminhos `.claude/...` antigos dentro do plugin `beacon-sdd` apontam para arquivos que não existem

**Data:** 2026-10-27
**Status:** diagnosticado, correção **não implementada** (a ser feita em branch do framework home, depois
reinstalada com `scripts/setup-agentic.sh claude` / `scripts/upgrade.sh` e retestada num workspace consumer)
**Origem:** sessão de Claude Code no workspace consumer `bcs2`. O usuário rodou `/beacon-sdd:rebase` e a
segunda execução trouxe a instrução `Read .claude/skills/rebase/SKILL.md`, que não existe no projeto.
O usuário perguntou se todos os caminhos do plugin apontam para `.claude/` e se isso causa erro.
**Relacionado:** [`2026-10-26-run-command-skill-path.md`](./2026-10-26-run-command-skill-path.md)
(este documento é o caso geral; aquele trata só do `/run`) e
[`2026-10-26-session-init-claude-workspace-root.md`](./2026-10-26-session-init-claude-workspace-root.md)
(mesma classe de problema: o plugin roda fora do workspace e assume caminhos do projeto).

## Sintoma

Os comandos do plugin mandam o agente ler um arquivo em `.claude/skills/<nome>/SKILL.md`, relativo à raiz
do projeto. Esse arquivo não existe num workspace consumer, porque o setup **não** copia skills do
framework para o projeto (ver `CLAUDE.md`). O `Read` falharia com `File does not exist`.

Na prática o `/rebase` funcionou, porque o Claude Code já injeta o texto do `SKILL.md` do plugin quando o
comando roda. O erro fica escondido. O risco real está no `/run` (ver o spec relacionado).

## Causa raiz

A estrutura antiga instalava o framework em `.claude/` (agents, skills, commands, hooks). Depois ela virou
o plugin `beacon-sdd` (instalado em `~/.claude/plugins/...`). Os textos que citam o caminho antigo não
foram atualizados. A fonte canônica, em `agentic/`, tem 62 linhas com `.claude/`. A cópia instalada do
plugin (só `commands`, `skills`, `agents`, `hooks`) tem 32 linhas em 16 arquivos.

## Levantamento (fonte: `agentic/`)

### Grupo A — instrução de leitura com caminho quebrado (corrigir)

| Arquivo | Linha | Texto atual |
|---|---|---|
| `agentic/commands/rebase.md` | 5 | `Read .claude/skills/rebase/SKILL.md` |
| `agentic/commands/clone.md` | 5 | `Read .claude/skills/clone/SKILL.md` |
| `agentic/commands/kb-refresh.md` | 5 | `Read .claude/skills/kb-refresh/SKILL.md` |
| `agentic/commands/kb-concentrator.md` | 5 | `Read .claude/skills/kb-concentrator/SKILL.md` |
| `agentic/commands/setup-workspace.md` | 5 | `Read .claude/skills/setup-workspace/SKILL.md` |
| `agentic/commands/run.md` | 8 | `Read .claude/skills/run-pipeline/SKILL.md` |
| `agentic/skills/run/SKILL.md` | 10 | `Read .claude/skills/run-pipeline/SKILL.md` |

O `run-pipeline/SKILL.md` tem `disable-model-invocation: true`. Ele só carrega quando o comando `/run`
roda e não aparece na lista de skills. Se o caminho falhar, o agente pode seguir o pipeline de memória,
sem avisar.

### Grupo B — referência em texto (baixo impacto, ajustar)

| Arquivo | Linha(s) | Observação |
|---|---|---|
| `agentic/agents/do.md` | 46 | cita `.claude/skills/run-pipeline/SKILL.md` |
| `agentic/agents/qa.md` | 35 | idem |
| `agentic/agents/summary.md` | 16 | idem |
| `agentic/agents/scrum.md` | 66, 106 | idem |
| `agentic/skills/generate-spec/SKILL.md` | 105 | idem |
| `agentic/skills/run-pipeline/SKILL.md` | 699, 713, 723 | cita `.claude/agents/<name>.md`; o agente real é `beacon-sdd:<name>` |

### Grupo C — arquivos de modelo do mecanismo antigo (decidir)

`.claude/models.yml` e `.claude/models.user.yml` aparecem em
`agentic/skills/run-pipeline/references/model-plan.md` (linhas 8 e 13) e em
`agentic/skills/run-pipeline/SKILL.md` (linhas 65, 167, 729, 733).

O `CLAUDE.md` atual diz que todo agente usa `model: inherit` e que a troca opcional por instalação fica em
`agentic/models/claude.yml`. Então esses textos descrevem um mecanismo que já saiu (`apply-models.sh`,
`use_manual_models`). Decidir: remover ou atualizar para `agentic/models/claude.yml`.

### Grupo D — hook que confere o lugar errado

`agentic/hooks/session-verify.sh`, linha 66: `checkHookDir(".claude/hooks")`. Com o plugin, os hooks ficam
em `${CLAUDE_PLUGIN_ROOT}/hooks`, não no projeto. O hook nunca bloqueia (fail-open), então não gera erro,
mas confere um lugar que não existe mais. Ajustar para olhar a pasta do plugin, ou remover a checagem.

### Grupo E — referências corretas (não mexer)

- `agentic/skills/setup-workspace/SKILL.md` linhas 41, 62, 68, 69, 72: `~/.claude/mcp.json` e
  `~/.claude/settings.json` são os arquivos globais do usuário.
- `agentic/skills/setup-workspace/SKILL.md` linhas 184 e 188: procura skills e agents **do projeto** em
  `<repo>/.claude/skills/` e `<repo>/.claude/agents/`. Skills do projeto continuam lá.
- `agentic/adapters/cursor/**`: descreve a migração do espelho `.claude/` para o Cursor.
- `agentic/adapters/claude/settings.json` e `agentic/adapters/claude/docs/runtime.md`: descrevem o espelho
  `.claude/` do modo antigo (sem plugin). Marcar como legado se esse modo ainda existir; senão, remover.

## Correção proposta

1. **Grupo A.** Trocar a leitura por caminho pela invocação da skill, que não depende de caminho:
   - `rebase`, `clone`, `kb-refresh`, `kb-concentrator`, `setup-workspace`: "Invoke the `<nome>` skill
     with the Skill tool" (nome `beacon-sdd:<nome>`).
   - `run`: o `run-pipeline` não é invocável pelo modelo. Usar `${CLAUDE_PLUGIN_ROOT}/skills/run-pipeline/SKILL.md`
     (o plugin já usa essa variável em `hooks/hooks.json`) e confirmar que ela está disponível no texto do
     comando. Se não estiver, tirar o `disable-model-invocation` do `run-pipeline`. Detalhes no spec do `/run`.
   - Manter a regra "não confiar na memória no primeiro turno de um `/run` novo".
2. **Grupo B.** Trocar `.claude/skills/run-pipeline/SKILL.md` por "skill `run-pipeline`" e
   `.claude/agents/<name>.md` por "agente `beacon-sdd:<name>`".
3. **Grupo C.** Atualizar ou remover as referências a `models.yml` / `models.user.yml`.
4. **Grupo D.** Ajustar o `checkHookDir` do `session-verify.sh`.

## Verificar depois

- Repetir a contagem: `grep -rn "\.claude/" agentic/commands agentic/agents agentic/skills agentic/hooks`.
  O que sobrar deve ser só do Grupo E.
- Rodar `/beacon-sdd:rebase`, `/clone` e `/run` num workspace consumer e confirmar que nenhum `Read` falha.
- Conferir `agentic/adapters/cursor/rules/run-pipeline-trigger.mdc` (mesmo ponto do spec do `/run`).
- Lembrar que a cópia em `~/.claude/plugins/...` é gerada. Qualquer edição direta lá se perde na próxima
  instalação. A correção entra em `agentic/` e depois passa por `setup-agentic.sh` / `upgrade.sh`.
