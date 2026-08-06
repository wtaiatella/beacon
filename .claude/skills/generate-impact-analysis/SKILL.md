---
name: generate-impact-analysis
description: "Plain-language impact/complexity/blocker triage template for the /ticket-intake persona. Produces impact-analysis.md: what the ticket is about, likely modification points, repos involved, complexity signal, and blockers/related work — written for a reader with no depth in this codebase or the business domain. Investigative recon, not requirements/design (that stays /prd's and /spectech's job)."
---

# Generate Impact Analysis

## When to Use

- After `ticket-intake` has written `ticket.md` (and its **Related tickets** section) for a
  freshly-fetched Jira issue.
- Any time `/ticket-intake` needs to produce or refresh `impact-analysis.md` for a ticket folder.

Output format is **normative**: follow section order exactly. This document reports what was
**found** by looking (git history, repo greps, related-ticket digs) — it does not propose a
design or make a scope decision. If nothing was found for a section, say so explicitly; do not
omit the section or fabricate a finding to fill it.

## Output Location and Naming

- **Directory:** `docs/specs/{slug}/` (the ticket's working folder)
- **Filename:** `impact-analysis.md` (always this name)
- **Metadata:** record `"impact_analysis": "done"` in `_state.json.steps` and a short line in
  `_notes.md` — schema and convention owned by the `ticket-workflow` skill.

## Audience and Language Contract

The reader is a developer who has **never touched this codebase** and has **no background** in
the ticket's business domain (e.g. Brazilian tax/accounting rules for `BG-*` tickets). Every
sentence must survive being read by that person with zero extra lookups.

- Write in the **ticket's own language** (usually Portuguese for `BG-*` / Brazilian-tax tickets;
  match `ticket.md`'s language otherwise). Do not silently switch languages mid-document.
- Define any domain or technical term the first time it's used, in plain words, in parentheses —
  don't assume the reader knows what a CFOP, an `operationType`, or a "natureza da operação" is.
- Short sentences. Concrete, not abstract. Prefer "o motor não sabe calcular impostos para esse
  tipo de operação" over "a matriz de operationTypes carece da entrada correspondente".
- State uncertainty honestly: "não encontramos nada" / "não temos certeza, mas é provável que..."
  — never assert a finding you didn't actually verify by running a search or reading a file.
- Avoid pasting raw code. If code must be pointed at, describe in one sentence what it does
  instead of (or right before) the snippet, and keep any snippet under ~10 lines.
- Every claim of the form "X already exists" / "Y is missing" / "Z is blocked" must trace to a
  concrete piece of evidence recorded in the **Evidências** section — no unverified assertions.

## How to Gather the Findings (before writing)

0. **Sync the workspace first.** Follow the `ticket-workflow` skill's "Workspace repo sync"
   section for every child repo before reading any file content or grepping: clean repos get
   checked out to their default branch and pulled (`git pull --rebase`); dirty repos are left
   alone and read via `git show origin/<default-branch>:<path>` instead of the working tree. Skip
   this only if it was already done earlier in the same `/ticket-intake` run. Every finding below
   depends on this — a read taken from a stale or unrelated branch is not evidence.
1. **Related-ticket dig.** For every ticket key already noted in `ticket.md`'s Related tickets
   section, search every child repo in the workspace (see the session-init inventory):
   - `git -C <repo> log --all --oneline -i --grep="<KEY>"`
   - `git -C <repo> branch -a | grep -i "<KEY>"`
   - If a branch/commits exist: check whether merged (`git -C <repo> merge-base --is-ancestor
     origin/<branch> origin/<base_branch>`) and inspect the diff
     (`git -C <repo> diff <base>...<branch> --stat`, then read the changed files) to see whether
     it already covers this ticket's ask, partially covers it, or is unrelated despite the name
     match.
   - If a candidate branch's GitLab MR state (open/merged, approvals, pipeline) would materially
     change the triage and local git alone can't tell you: escalate
     `REQUEST_MAIN: mcp-gitlab <query>` per the Flat Orchestration contract — do **not** call
     `mcp__GitLab__*` tools directly from this persona (they are not in its toolbox).
2. **Modification-point scan.** Pull the concrete domain terms out of the ticket description
   (error message text, `operationType`/field/endpoint names, CFOP codes, etc.) and grep every
   child repo for them to see which repos/modules already reference the concept — those are the
   likely modification points. Prefer exact strings from the ticket over paraphrases.
3. **Repo involvement.** A repo counts as "involved" only on a real hit from step 1 or 2 — not on
   a guess. Absence of hits is itself a finding ("procuramos e não achamos nada em `<repo>`").

## Impact Analysis Template (Required Order)

```markdown
# Análise de Impacto (linguagem simples) — {TICKET-KEY}

_Gerado por /ticket-intake em {YYYY-MM-DD}. Isto é uma triagem investigativa — não é o PRD nem o
spec técnico. Reporta o que foi encontrado ao procurar, não o que deveria ser construído._

## Em resumo

2-4 frases, sem jargão, que qualquer pessoa da equipe entende de primeira: o que o cliente/usuário
está tentando fazer, o que está impedindo isso, e (se já souber) o que resolve.

## O que é isto, sem jargão

Explique o cenário de negócio por trás do ticket em termos simples. Se algum termo técnico ou
contábil/tributário for inevitável, defina-o entre parênteses na primeira aparição. Uma analogia
curta é bem-vinda se ajudar.

## Isto é correção, novidade ou melhoria?

Uma linha de classificação — **Correção de bug** | **Nova funcionalidade** | **Melhoria/incremento**
— com 1-2 frases de justificativa em linguagem simples.

## Onde isso mora hoje (pontos de modificação prováveis)

Lista dos arquivos/módulos/repositórios que provavelmente precisam mudar, cada item com:
- o caminho/módulo,
- uma frase em português simples do que aquele pedaço faz,
- se é **confirmado** (achamos evidência concreta — cite-a) ou **palpite razoável** (não achamos
  evidência direta, é inferência).

Se nada foi encontrado, diga isso explicitamente em vez de adivinhar.

## Projetos envolvidos

| Repositório | Envolvido? | O que esse repositório faz (uma frase) | Evidência |
|---|---|---|---|
| `<repo>` | Sim/Não | ... | comando/achado que sustenta a linha |

Inclua toda a lista de repositórios do workspace (não apenas os envolvidos) — um "Não" explícito
com a busca que não achou nada é tão útil quanto um "Sim".

## Complexidade estimada

**Baixa** | **Média** | **Alta**, com os motivos concretos (não apenas a palavra). Use este
guia de sinais:

- **Baixa:** um só repositório; existe um padrão parecido pra copiar; é mudança de
  dado/configuração sem lógica nova; ou já existe trabalho pronto cobrindo isto (só falta
  aprovar/mesclar).
- **Média:** mais de um módulo no mesmo repositório, ou lógica nova seguindo um padrão já
  existente; exige entender a interação com outra funcionalidade/ticket; nenhum trabalho pronto
  encontrado mas o escopo parece contido.
- **Alta:** mais de um repositório precisa mudar; não há padrão parecido pra copiar; requisitos
  ambíguos ou regra de negócio complexa que precisa validação com especialista; muda modelo de
  dados ou lógica central usada por muitos fluxos.

Deixe explícito: **isto é um sinal de primeira triagem, não uma estimativa final** — o
dimensionamento real é trabalho do `/spectech`/`/tasks`.

## Bloqueios e trabalho relacionado

Diga com todas as letras se o ticket parece: já resolvido em outro lugar (duplicado), bloqueado
por outro ticket/MR, ou dependente de algo que ainda não foi entregue. Nomeie o ticket/branch/MR
e seu estado atual (aberto/fechado/mesclado/aprovado). Se nada foi encontrado, diga "não
encontramos nenhum bloqueio ou trabalho relacionado" explicitamente.

## Como isso foi apurado (evidências)

Lista curta, mais técnica, dos comandos/buscas/tickets consultados — para auditoria e para que o
próximo passo (`/prd`, um humano, ou outro agente) possa reproduzir ou aprofundar a investigação.
Inclua sempre o resultado do sincronismo dos repositórios (passo 0): quais repos foram atualizados
para o branch padrão, quais ficaram de fora (e por quê — working tree sujo), já que isso afeta a
confiabilidade de todos os outros achados desta seção.

## O que isto NÃO é

Uma frase lembrando que isto não substitui `/prd` (requisitos) nem `/spectech` (design técnico) —
é só o ponto de partida.
```

## Quality Bar Before Handoff

- [ ] Every child repo was synced to its default branch first (or explicitly skipped as dirty,
      with a working-tree-safe fallback used) — see the `ticket-workflow` skill's "Workspace repo
      sync" section
- [ ] Every section present in order; no section silently skipped (explicit "não encontramos" instead)
- [ ] Written in the ticket's language, zero unexplained jargon
- [ ] Every "found"/"missing"/"blocked" claim traces to an entry in **Como isso foi apurado**
- [ ] Complexity rating includes concrete reasons, not just the label, and flags itself as
      preliminary
- [ ] Repo involvement table covers every child repo in the workspace, not only the ones that hit
- [ ] No raw code dumps longer than ~10 lines
- [ ] File saved to `docs/specs/{slug}/impact-analysis.md`
- [ ] `_state.json.steps.impact_analysis` set to `"done"` and a matching `_notes.md` entry
      appended — per the `ticket-workflow` skill

## Notes

- **This is recon, not design.** Do not propose a solution, do not write acceptance criteria, do
  not size effort in story points/hours — that's `/prd`'s and `/spectech`'s job. This document
  only reports what already exists and what was found by looking.
- **Evidence over confidence.** A finding is only as good as the command that produced it. When
  in doubt, run one more grep rather than asserting from memory of similar tickets.
- **Related work is the highest-value finding.** If a branch/MR/ticket already covers this ask
  (merged, open, or abandoned), that changes everything about what happens next — surface it
  prominently in **Em resumo**, not buried at the bottom.
