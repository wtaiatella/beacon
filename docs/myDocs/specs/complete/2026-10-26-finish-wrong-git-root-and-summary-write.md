# `pipeline-finish.sh` usa a raiz do workspace como repo git; `summary` não consegue gravar `summary.md`

**Data:** 2026-10-26
**Status:** diagnosticado, correção **não implementada** (a ser feita em branch do framework home, depois
reinstalada com `scripts/setup-agentic.sh claude` / `scripts/upgrade.sh` e retestada num workspace consumer)
**Origem:** sessão de Claude Code no workspace consumer `bcs1`, ticket BG-11575 (repo `br-tax-engine`,
branch `fix/BG-11575`, 8 commits locais). Dois problemas no fim do `/run` (§8 summary e §9 Finish).
**Relacionado:** [`2026-10-26-run-command-skill-path.md`](./2026-10-26-run-command-skill-path.md).

## Problema A — `pipeline-finish.sh` age na raiz do workspace

### Sintoma

No §9 o orquestrador avisou: o script "só atua no workspace raiz (não no `br-tax-engine`) e um push aqui
empurraria a `main` indevidamente". Ele rodou o script com `--no-commit --push false` só para a auditoria
e deixou o push do engine fora do script. Isso se repete em todo ticket de um workspace de repos filhos.

### Causa raiz

`scripts/hooks/pipeline-finish.sh`, função `resolve_git_root` (linhas ~16–35):

- se não existe `<ticket>/_run/attach-target.txt`, devolve `$ROOT` (raiz do workspace);
- `attach-target.txt` é do mecanismo multi-root (`attach-project.sh`). Este fluxo não usa. No BG-11575 a
  pasta `_run/` tem só `diffs`, `explorer`, `scanners`, `timeline.md`.
- o `_state.json` do ticket já tem `"repo": "br-tax-engine"` e `"branch": "fix/BG-11575"`, mas o script
  não lê esses campos.
- `pipeline-commit.sh` tem `--repo <dir>`. `pipeline-finish.sh` não tem.
  `agentic/skills/run-pipeline/SKILL.md` (linha ~308) fala em "Optional `--repo`" para o commit, e o
  Finish não tem como imitar isso.

Efeito: `git add -A`, `git commit` e `git push` do Finish rodam na `main` do workspace, não no repo que mudou.

### Correção proposta

1. Adicionar `--repo <dir>` ao `pipeline-finish.sh`, com a mesma validação do `pipeline-commit.sh`
   (linhas ~101–110).
2. Ordem de resolução do git root: `--repo` > `attach-target.txt` > `_state.json` campo `repo`
   (`$ROOT/<repo>`) > `$ROOT`.
3. **Falhar com erro** se o ticket declara `repo` e o script ia cair em `$ROOT`. O padrão silencioso para
   a raiz é o que torna o push perigoso.
4. Aplicar o mesmo fallback do `_state.json` no `pipeline-commit.sh`, para os dois ficarem iguais.
5. Atualizar `agentic/skills/run-pipeline/SKILL.md` (§9 e a nota de multi-root, linha ~607) e
   `usage()` dos dois scripts.
6. Multi-repo: se o ticket mexer em mais de um repo, `_state.json.repo` pode ser lista. Decidir se o
   Finish roda uma vez por repo.
7. A auditoria (`audit-session-trace.py`) deve continuar a partir de `$ROOT` (o script já faz `cd "$ROOT"`).

### Verificar depois

- Ticket com `repo` no `_state.json` e sem `attach-target.txt`: o `git-root` impresso é o repo filho.
- Ticket sem `repo` e sem `--repo`: erro claro, sem commit nem push.
- Push só com `--push true` e nunca na `main`/`development` (regra do `AGENTS.md`).

## Problema B — o subagente `summary` não consegue gravar `summary.md`

### Sintoma

O agente `summary` devolveu o texto, mas o `Write` dele foi recusado com
"Subagents should return findings as text". O orquestrador gravou o arquivo ele mesmo, sem alterar o
conteúdo (mesmo contorno usado nos relatórios dos scanners).

### Causa raiz (parcialmente confirmada)

- A frase não aparece em `agentic/`, `.claude/`, no plugin instalado nem nos settings. Não vem de um hook
  do projeto.
- O `subagent-gate` só bloqueia branches protegidas de repos filhos, e `docs/specs` está na raiz do
  workspace, que ele exclui.
- Conclusão: a recusa vem da ferramenta Write do Claude Code, que impede subagentes de gravar arquivos com
  cara de relatório. **Não foi confirmado** na documentação da plataforma, e o mesmo bloqueio não foi visto
  com `qa` ou `prd` nesta sessão.
- Mesmo assim, `agentic/agents/summary.md` (passos 7–8 e linha ~71) manda gravar
  `<ticket>/summary.md` e lista Write nas ferramentas. O contrato depende de algo que a plataforma recusa.

### Correção proposta

1. Mudar o contrato do `summary`: devolver o texto completo e o orquestrador grava
   `<ticket>/summary.md`. Mesmo padrão dos relatórios dos scanners.
2. Ajustar `agentic/agents/summary.md`, o §8 de `run-pipeline/SKILL.md` e o comando `/summary`
   (uso standalone: aí o agente é o próprio main loop e pode gravar).
3. Conferir `qa` (`qa-report.md`) e `spec-validator` pelo mesmo risco e alinhar o contrato.

### Verificar depois

- Rodar `/run` até o §8 e confirmar que `summary.md` é gravado sem recusa e sem o orquestrador improvisar.
- Confirmar o motivo exato da recusa na documentação do Claude Code (ou com `claude-code-guide`).
