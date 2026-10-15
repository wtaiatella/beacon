# Modelo por agente configurável por instalação — `inherit` por padrão

**Data:** 2026-10-07
**Status:** implementado — um arquivo de override por adapter (`agentic/models/<target>.yml`), não
um único compartilhado (ver "Resolvido na implementação" — revisão no mesmo dia, a partir de uso
real com Claude + Cursor na mesma máquina); `apply-models.sh`/`.cursor/models.yml` do Cursor
mantidos como mecanismo dinâmico adicional, não migrados
**Origem:** discussão em sessão — a assinatura/modelo disponível varia muito por ambiente (ex.:
Google + Antigravity em casa, Cursor + Claude no trabalho); travar `model: haiku`/`model: inherit`
no frontmatter canônico do agente trata todo ambiente como igual, o que não é real.
**Relacionado:** resolve o ponto "`.model-snapshot` / troca de modelo por step é mecanismo só do
Cursor" deixado estacionado em
[`2026-10-06-eliminate-sessions-ticket-scoped-state.md`](./2026-10-06-eliminate-sessions-ticket-scoped-state.md)
— ver "Pontas relacionadas" naquela spec.

## Problema

Hoje o modelo de cada agente é fixo no **frontmatter** do arquivo canônico
(`agentic/agents/<nome>.md`, campo `model:`). Levantamento atual (24 agentes):

| `model:` | Agentes |
|---|---|
| `haiku` (15) | `codebase-explorer`, `data-reviewer`, `dev-reviewer`, `do`, `mcp-arc`, `mcp-confluence`, `mcp-gitlab`, `mcp-jira`, `mcp-glean`, `plan-reviewer`, `pre-plan-triage`, `scrum`, `spec-validator`, `sre-reviewer`, `summary` |
| `inherit` (9) | `data`, `dev`, `fix`, `kb`, `prd`, `qa`, `security-scanner`, `spectech`, `sre`, `tasks` |

Isso é o **mesmo arquivo**, instalado por `setup-agentic.sh` em qualquer máquina/IDE — não há
onde um usuário diga "no meu Antigravity de casa eu não tenho um modelo equivalente ao Haiku
disponível, usa outra coisa" ou simplesmente "aqui eu só quero `inherit` em tudo". O único
mecanismo de override hoje é `.cursor/models.yml` / `.cursor/models.user.yml` (lido por
`apply-models.sh`) — e é **Cursor-only**, opcional, não teve seu formato pensado para os outros
adapters.

## Decisão

1. **Novo padrão canônico: todo agente nasce `model: inherit`.** Remove o hardcode de `haiku` do
   frontmatter de todos os 15 agentes listados acima. `inherit` significa "usa o modelo da sessão
   atual" — funciona em qualquer ambiente, sem assumir que um tier econômico equivalente a Haiku
   exista ou valha a pena ali.
2. **Um arquivo de config local por instalação, por adapter.** Não versionado (como
   `.cursor/models.user.yml` hoje), lido por `scripts/setup-agentic.sh` no momento da
   instalação/reinstalação **daquele adapter**. Nele, o usuário pode opcionalmente mapear
   `<agente>: <model>` — qualquer agente omitido fica `inherit` (o padrão canônico). Mesmo schema
   em todo adapter, mas **arquivos separados** — usar Claude e Cursor na mesma máquina/checkout
   não significa compartilhar override (razão da revisão: ver "Resolvido na implementação").
3. **Aplicação depende do mecanismo do IDE** (documentado, não escondido):
   - **Claude Code:** o `model:` é estático por arquivo de agente — `setup-agentic.sh claude`
     passa a **templatizar** a cópia instalada: lê `agentic/agents/<nome>.md` (sempre `inherit` na
     fonte), aplica o override de `agentic/models/claude.yml` se existir para aquele agente, e
     escreve o resultado no plugin instalado. Reinstalar aplica a config de novo (idempotente).
   - **Cursor:** mantém o mecanismo dinâmico já existente (`apply-models.sh`, overrides por step)
     **e** passa a também aplicar o override estático de `agentic/models/cursor.yml` na instalação
     — os dois convivem (estático na instalação, dinâmico por step durante `/run`).
   - **Antigravity:** sem mecanismo ainda (stub) — quando for construído, segue a mesma convenção
     (`agentic/models/antigravity.yml`).

## Nome e formato do arquivo (final)

`agentic/models/<target>.yml` por adapter (`claude.yml`, `cursor.yml`, …) — gitignorado
(`agentic/models/*.yml` no `.gitignore`, com exceção de `example.yml`, que é o template tracked).
Formato mínimo, igual em todos:

```yaml
# Omitido = inherit (padrão). Só liste o que quiser diferente.
do: haiku
summary: haiku
scrum: haiku
```

## Escopo da migração

| Item | Ação |
|---|---|
| 15 agentes com `model: haiku` hardcoded | trocar frontmatter pra `model: inherit` |
| `scripts/setup-agentic.sh` | ler o arquivo de config local (se existir) e templatizar o `model:` na cópia instalada (Claude); repassar pro mecanismo do Cursor |
| `scripts/tools/apply-models.sh` | migrar para ler o novo arquivo único em vez de `.cursor/models.yml`/`.cursor/models.user.yml` próprios (ou manter como fallback de compatibilidade) |
| `agentic/AGENTS.md` | nenhuma mudança de conteúdo (model selection já está marcado como "specific to each IDE adapter", corretamente fora do arquivo compartilhado) |
| `agentic/adapters/claude/CLAUDE.md` | atualizar a seção "Model Selection" — já não há tiers fixos por categoria de agente; descrever o novo arquivo de config local |
| `agentic/adapters/cursor/rules/00-workspace-router.mdc` | idem, apontando pro mesmo arquivo |
| `.gitignore` | adicionar o novo arquivo de config local |

## Resolvido na implementação (2026-10-07)

- **Escopo do arquivo: por checkout** — mas **um arquivo por adapter**, não um único compartilhado
  (revisão no mesmo dia: usar Claude e Cursor na mesma máquina/checkout — terminal vs. editor —
  exigiria editar e reinstalar alternadamente com um arquivo só). Formato final:
  `agentic/models/<target>.yml` (`claude.yml`, `cursor.yml`, gitignored), template único em
  `agentic/models/example.yml` (tracked). Cada adapter só lê o seu — editar um nunca afeta o outro,
  mesmo checkout.
- **`.cursor/models.yml`/`.cursor/models.user.yml` mantidos como estão** (mecanismo dinâmico
  adicional, não migrado) — o novo arquivo por-adapter cobre o caso estático (instalação); o
  dinâmico do Cursor continua existindo em paralelo pra overrides por step durante `/run`.
- **Aviso, não erro,** para nome de agente desconhecido no override — `setup-agentic.sh` segue
  instalando o resto normalmente.

## O que foi feito

- Removido `model: haiku` hardcoded de 15 agentes em `agentic/agents/*.md` — todos os 24 agentes
  agora nascem `model: inherit`.
- `agentic/models/example.yml` (novo, tracked) — template documentado do override, um por adapter.
- `.gitignore` — `agentic/models/*.yml` ignorado, com exceção explícita de `example.yml`.
- `scripts/setup-agentic.sh`:
  - `apply_model_overrides(<agents_dir>, <target>)` — lê `agentic/models/<target>.yml` linha a
    linha, reescreve o `model:` da cópia **instalada** por agente listado; avisa (não falha) em
    nome desconhecido.
  - Chamada em `install_claude_plugin` com `"claude"` (pós `cp -R agents`) e em `install_cursor`
    com `"cursor"` (pós `sync_dir_managed agents`).
  - `claude_plugin_source_stamp()` inclui o conteúdo de `models/claude.yml` (só o do Claude) no
    hash — editar só o override (sem tocar em `agentic/agents/`) já invalida o cache "already
    installed" e força reinstalação. (Corrigido um bug de `set -e` nessa mesma mudança —
    `[[ -f ... ]] && cat ...` abortava o script quando o arquivo não existia; trocado por `if`.)
- Testado ponta a ponta: overrides **diferentes e simultâneos** em `claude.yml` e `cursor.yml` no
  mesmo checkout, cada um aplicado só no adapter certo; aplicado e revertido corretamente; aviso de
  agente desconhecido confirmado; cache-invalidation confirmada.
- Docs atualizadas: `agentic/adapters/claude/CLAUDE.md`, `agentic/adapters/cursor/rules/00-workspace-router.mdc`,
  `README.md` (seção Models) — descrevem o novo mecanismo em vez da lista fixa de tiers.
