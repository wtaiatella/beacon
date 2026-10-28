# `/run` manda ler `.claude/skills/run-pipeline/SKILL.md`, que não existe num workspace consumer

**Data:** 2026-10-26
**Status:** diagnosticado, correção **não implementada** (a ser feita em branch do framework home, depois
reinstalada com `scripts/setup-agentic.sh claude` / `scripts/upgrade.sh` e retestada num workspace consumer)
**Origem:** sessão de Claude Code no workspace consumer `bcs1`. O usuário rodou
`/beacon-sdd:run o ticket BG-11575 não finalizou o fluxo, ...`. O agente respondeu que o `SKILL.md`
"não está no caminho indicado".
**Relacionado:** [`2026-10-26-session-init-claude-workspace-root.md`](./2026-10-26-session-init-claude-workspace-root.md)
(mesma classe de problema: o plugin roda fora do workspace e assume caminhos do projeto).

## Sintoma

O comando `/run` começa com `Read` de um caminho fixo. O `Read` volta `File does not exist`. O agente
precisa procurar o skill por conta própria. Nesta sessão ele achou e seguiu, mas gastou passos a mais.
Em outra sessão ele pode não achar, ou pode seguir de memória (o próprio `run.md` proíbe isso).

## Causa raiz

`agentic/commands/run.md`, linha 8:

> **Read** `.claude/skills/run-pipeline/SKILL.md` (use the Read tool) ...

O caminho é relativo à raiz do projeto. Ele só existe se o skill estiver copiado para `.claude/skills/`.
Com o plugin `beacon-sdd`, o setup **não** copia skills do framework para o projeto (ver `CLAUDE.md`).
Os caminhos reais são:

- fonte: `agentic/skills/run-pipeline/SKILL.md` (só no framework home);
- instalado: `~/.claude/plugins/cache/beacon-sdd-local/beacon-sdd/0.0.0/skills/run-pipeline/SKILL.md`;
- no workspace `bcs1`, `.claude/skills/` existe mas não tem `run-pipeline`.

A cópia instalada do `run.md` (linha 8) tem o mesmo caminho.

## Correção proposta

Em `agentic/commands/run.md`, trocar o passo 1 por uma destas formas:

1. **Preferida:** "Invoke the `run-pipeline` skill with the Skill tool" (nome `beacon-sdd:run-pipeline`).
   Não depende de caminho.
2. Alternativa: `${CLAUDE_PLUGIN_ROOT}/skills/run-pipeline/SKILL.md`, se a variável estiver disponível
   no texto do comando.

Manter a regra "não confiar na memória no primeiro turno de um `/run` novo".

## Verificar depois

- Procurar outros comandos/agentes com caminho `.claude/skills/...` fixo:
  `grep -rn "\.claude/skills/" agentic/commands agentic/agents`.
- Rodar `/run` num workspace consumer e confirmar que o skill carrega sem `File does not exist`.
- O adaptador Cursor tem `run-pipeline-trigger.mdc`; conferir se o caminho de lá está certo.
