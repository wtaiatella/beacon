# `session-init` no Claude Code não encontra a raiz do workspace — repos e tickets não são injetados

**Data:** 2026-10-26
**Status:** diagnosticado, correção **não implementada** (a ser feita em branch do framework home, depois
reinstalada com `scripts/setup-agentic.sh claude` / `scripts/upgrade.sh` e retestada num workspace consumer)
**Origem:** sessão de Claude Code no workspace consumer `bcs1`. Ao abrir um chat novo, o contexto de
SessionStart veio com `(none detected yet — clone target repos ...)` e
`No ticket folders in docs/specs/. (scripts/tools/spec-status.sh not found — run setup if applicable)`,
embora o workspace tivesse 3 repos filhos clonados, 8 pastas de ticket e o `spec-status.sh` instalado.
**Relacionado:** [`2026-10-06-eliminate-sessions-ticket-scoped-state.md`](./2026-10-06-eliminate-sessions-ticket-scoped-state.md)
(o `session-init` é o hook que injeta a visão de repos/specs descrita ali).

## Sintoma

Em todo SessionStart do Claude Code, o `session-init` entrega um inventário vazio:

- **Repos:** `(none detected yet ...)` — mesmo com `br-tax-devops/`, `br-tax-engine/` e `br-tax-ui/` na raiz.
- **Specs:** `No ticket folders in docs/specs/. (scripts/tools/spec-status.sh not found ...)` — mesmo com
  `scripts/tools/spec-status.sh` presente e `docs/specs/` com tickets.

O agente passa a sessão sem saber quais repos existem, em qual branch estão, nem quais tickets estão abertos.
O hook falha em modo aberto (sem erro visível), então o problema passa despercebido.

## Causa raiz

O hook instalado roda **de dentro do cache do plugin**
(`~/.claude/plugins/cache/beacon-sdd-local/beacon-sdd/0.0.0/hooks/session-init.sh`), não de dentro do workspace.
Ele depende de `workspaceRootOf()` para saber onde está o workspace.

Fonte: `agentic/hooks/lib/hook-protocol.js`, função `workspaceRootOf(input, fallback)` (linha ~134).
Ela só reconhece:

1. `input.workspacePaths[0]` — payload do Cursor/Antigravity;
2. `input.workspace_roots[0]` — payload do Cursor/Antigravity;
3. `process.env.HOOK_ROOT`;
4. o `fallback` (o `session-init.sh` passa `""`).

O payload de SessionStart do **Claude Code** não traz nenhum desses campos. Traz **`cwd`** (e
`CLAUDE_PROJECT_DIR` no ambiente). A mesma lib já lê `input.cwd` em `cwdOf()` (linha ~121), mas
`workspaceRootOf()` não o usa.

Cadeia de falha no `session-init.sh`:

1. `workspaceRootOf` retorna `""` → `WS_ROOT` vazio.
2. O fallback sobe a partir do script procurando `scripts/tools/spec-status.sh`. O script mora no cache do
   plugin, então nunca encontra.
3. Último recurso: `ROOT="$(cd "$DIR/../.." && pwd)"`. Com o script em `.../0.0.0/hooks/`, isso cai em
   `.../beacon-sdd/` — dentro do plugin.
4. Nesse `ROOT` não há subpastas com `.git` (repos = vazio) e não há `scripts/tools/spec-status.sh`
   (specs = mensagem de "not found").

O comentário do script ("The installed Cursor copy lives at .cursor/hooks/beacon/ ... DIR/../.. lands in
.cursor") mostra que o fallback foi pensado para a instalação do Cursor, que vive dentro do workspace. Para o
plugin do Claude Code, que vive fora do workspace, o fallback nunca acerta.

## Reprodução

Executado no workspace `bcs1`, chamando o hook instalado diretamente:

| Cenário | Resultado |
|---|---|
| stdin `{"hook_event_name":"SessionStart","cwd":"<workspace>","session_id":"x"}`, sem `HOOK_ROOT` | **Falha**: repos `(none detected)`, specs `spec-status.sh not found` |
| stdin `{}` | **Falha**: igual, e ainda `WORKSPACE.md is not in the workspace root` |
| mesmo payload com `HOOK_ROOT=<workspace>` | **Funciona**: lista `br-tax-devops`, `br-tax-engine` (com branch) e `br-tax-ui`, e a tabela completa de specs |

`CLAUDE_PROJECT_DIR` estava vazio no shell comum, então não dá para testá-lo de fora. Ele só existe no
ambiente em que o Claude Code executa hooks — validar no teste real.

Cópia do cache e cópia do marketplace do plugin são idênticas (`diff` sem diferença), então não é
instalação desatualizada: o defeito está na fonte.

## Correção proposta

Em `agentic/hooks/lib/hook-protocol.js`, `workspaceRootOf`, manter a ordem atual e acrescentar o Claude
**antes** do `fallback`:

```js
function workspaceRootOf(input, fallback = process.cwd()) {
   if (input && Array.isArray(input.workspacePaths) && input.workspacePaths.length > 0) {
      return input.workspacePaths[0];
   }
   if (input && Array.isArray(input.workspace_roots) && input.workspace_roots.length > 0) {
      return input.workspace_roots[0];
   }
   if (process.env.HOOK_ROOT) {
      return process.env.HOOK_ROOT;
   }
   if (process.env.CLAUDE_PROJECT_DIR) {          // Claude Code: raiz do projeto
      return process.env.CLAUDE_PROJECT_DIR;
   }
   if (input && typeof input.cwd === 'string' && input.cwd) {   // Claude Code: payload
      return input.cwd;
   }
   return fallback;
}
```

Por que `CLAUDE_PROJECT_DIR` antes de `cwd`: o `cwd` do payload pode ser uma subpasta se o usuário abrir o
Claude dentro de um repo filho (ex.: `br-tax-engine/`). `CLAUDE_PROJECT_DIR` aponta para a raiz do projeto.

## Pontos a decidir na implementação

1. **`cwd` dentro de um repo filho.** Se não houver `CLAUDE_PROJECT_DIR`, usar `cwd` direto devolve a
   subpasta. Opção: subir a partir do `cwd` até achar `scripts/tools/spec-status.sh` (mesmo critério do
   walk que já existe no `session-init.sh`), em vez de aceitar o `cwd` cru.
2. **Efeito em outros hooks.** `workspaceRootOf` é lib compartilhada. Conferir quem mais a chama
   (`subagent-gate`, `before-shell`, `before-read`, `audit-log`, `session-verify`) — a mudança pode alterar
   o comportamento deles no Claude, em geral para melhor (hoje podem estar operando com raiz errada
   sem avisar). O `subagent-gate` em particular depende de achar o repo filho correto.
3. **Falha silenciosa.** O hook falha em modo aberto sem sinalizar. Avaliar se, quando `ROOT` não contém
   `scripts/tools/spec-status.sh`, o hook deve avisar explicitamente ("raiz do workspace não resolvida")
   em vez de imprimir "No ticket folders", que parece um estado válido e induz a erro.
4. **Teste automatizado.** Não há cobertura para o payload do Claude. Adicionar em `scripts/tools/tests/`
   um caso: stdin com `cwd` apontando para um workspace temporário com um repo `.git` e um
   `scripts/tools/spec-status.sh`, esperando o repo na saída.

## Verificação depois de implantar

1. Reinstalar: `scripts/setup-agentic.sh claude` (ou `scripts/upgrade.sh` no consumer).
2. Abrir um chat novo no workspace consumer e conferir que o contexto de SessionStart traz a lista de repos
   com branch e a tabela de specs.
3. Repetir abrindo o Claude **dentro de um repo filho** (ponto 1 acima).
4. Rodar o hook manualmente com o payload do Claude (cenário da tabela de reprodução) e comparar.
