---
name: bcs-repro
description: Places durable ticket fixtures by incrementing the existing container for that artifact kind (shared seed file or sibling folder). Ticket-named files/folders are last resort. Use when running /bcs-repro or when a ticket would invent mugil/test/fixtures/<TICKET>/.
---

# bcs-repro — fixture placement

A **fixture** is a versioned file (or record) the test suite loads to replay one customer-like situation. It is not the mocha file.

Read this skill **before** writing any file under `*/test/` during `/bcs-repro` or when `/dev` promotes repro artifacts into CI.

## Decision procedure (always)

Do **not** start from a catalog of ticket names. For **each** artifact, answer in order:

1. **What kind is this?** (calc HTTP request, template/calc-response oracle, catalog citation, NCM, rule-set, subscription citation, mocha spec, …)
2. **Where do existing items of that kind already live?** List the directory. Open a few siblings. Note the container:
   - **One shared JSON/cjson array** (`citations.cjson`, `ncms.cjson`, …) → the container is that **file**.
   - **Versioned calc/template trees** (`mugil/test/_input/v3-goods/`, `v3-services/`, `v2-goods/`, `eucinostomus/test/_input/v3-goods/`, …) → pick **API version + goods vs services**, then the existing subfolder (`feat`, `prod`, `difa`, `qa`, …). Count files: hundreds in `v3-goods/` beat a handful of `bg-XXXX/` folders.
   - **Many mocha specs** in `mugil/test/calculations/` → add a sibling spec.
3. **Increment that container.** Same shape, same naming, same load path.
4. **Last resort only:** create a ticket-named file or folder when you **cannot identify** a container. Write in `repro.md` why. A few tickets opened `mugil/test/_input/bg-11273/` — that is **not** the pattern to copy.

**Never** invent a third scheme next to a canonical one (e.g. `citations-bg-11356.cjson` beside `citations.cjson`, or `_input/bg-11356/` beside `_input/v3-goods/`). A one-off sibling like `subscriptions-citations-bg-11217.cjson` is **not** a pattern to copy.

### Increment means

| Container you found | What to do |
|---------------------|------------|
| Shared `.cjson` / `.json` **array** | **Append** the new object(s). Match existing formatting. Prefer **reuse** of an existing row + field override. |
| `mugil/test/_input/v{2,3}-goods|services/` (and `eucinostomus/test/_input/v3-goods/` etc.) | Add a **sibling file** in the matching version/type subfolder (`feat` / `difa` / `prod` / …). Goods v3 calc requests look like `nfe-<cnpj>-BG-<NNNN>-<slug>-req.json`. |
| Mocha files in `*/test/calculations/` or `*/test/funcs/` | Add a sibling spec named like the others. Point it at the payload you just added. |

`v3-goods-calculation-all-test.js` globs `mugil/test/_input/v3-goods/*/nfe-*-req.json` and pairs each with `_output`. `eucinostomus` **goods-int** globs **every** `.json` under `eucinostomus/test/_input/v3-goods/*/` as `POST /v3/invoices/goods` (inutilização + emit). Only drop a file there if it is a valid invoice payload. A calc **response** used as template oracle is a different kind — keep it in the mocha (trimmed) or in ticket `test-fixtures/`; do **not** park it in `v3-goods/prod`.

Ticket-folder **archive** (`docs/specs/…/test-fixtures/`) is separate — see below. It does not replace the product-repo increment.

## Ticket-folder archive (required)

Files **created and used during repro/tests** must also be stored **inside the ticket folder** for later reference (the delta you appended, plus sandbox helpers).

Use a **dedicated subdirectory** so they do **not** mix with `prd.md`, `spectech.md`, `tasks.md`, `_notes.md`, `ticket.md`, `qa-report.md`, `summary.md`, `repro.md`.

```
docs/specs/<YYYY-MM-DD>-<TICKET-KEY>-<slug>/
├── prd.md, spectech.md, tasks.md, repro.md, …   # base documents — keep these at the folder root
├── attachments/                                 # originals downloaded from Jira — do not dump generated test files here
└── test-fixtures/                               # generated/used test inputs — later reference
    ├── …-req.json / overlay records / repro-*.js
```

- **Do not** drop `.json` / `.xml` / `.cjson` / `repro-*.js` next to `prd.md`.
- **Do not** put generated fixtures into `attachments/`.
- The ticket folder is the audit trail; the product tree is what CI runs.
- List both in `repro.md` § Fixture resolution: (1) which canonical product file/folder was incremented, (2) `test-fixtures/` copies.

## Forbidden

- **`mugil/test/fixtures/`** — empty until BG-11356 invented it. Do not recreate.
- A new `*/test/fixtures/<TICKET-KEY>/` directory when the module already has `_input/` or `_database/`.
- Mixing calc payloads, production oracles, citation `.cjson`, and sandbox scripts in one new product folder.
- New `*-bg-<NNNN>.cjson` (or `index.js` merge of that file) when `test/_database/<kind>.cjson` already holds that kind.
- New `mugil/test/_input/bg-<NNNN>/` (or `eucinostomus/test/_input/bg-<NNNN>/`) when `v3-goods` / `v3-services` / `v2-*` already holds that API+type.
- Copying `subscriptions-citations-bg-11217.cjson` or `_input/bg-11273/` as “the way tickets do it”.

## Keep the set small

Prefer **one** calc request JSON that mocha asserts as the **after-fix** contract (fails on `base_branch`, passes on the fix branch). Extra product files only when:

- the template test needs a **production calc oracle** (before-fix response), or
- seed truly lacks a row and you must **append** it to the canonical `.cjson`.

Sandbox helpers (`repro-template.js`, `load-overlay.js`) belong in **`test-fixtures/`** on the ticket folder. Mocha should not need them.

## Realistic data

Clone a valid sibling record/file; change only fields that express the defect. Do not use `XX`/`foo` as business keys. Ticket-key `__uuid` / `documentCode` when you insert new rows so they are greppable inside the shared file.

## `repro.md` contract

Under **Fixture resolution**, name the **canonical product paths that were incremented** (e.g. `test/_database/citations.cjson`, `mugil/test/_input/v3-goods/feat/nfe-…-req.json`) and the ticket `test-fixtures/` copies. Under **Required integration tests**, the owning suite hint must match product paths (`mugil/test/calculations/…` + `_input/v3-goods/`, not `mugil/test/fixtures/` and not `_input/bg-XXXX/`).
