# Agent contract

Tool-neutral rules for Cursor, Claude Code, and any other coding agent in this repository.
Coding standards stay in `CODING_PRINCIPLES.md` and `.cursorrules`.
Deep-analysis doctrine lives in `OPERATING_MANUAL.md`. This file is documentation, tests, and the team quality bar.

## Ownership (do not invent a parallel system)

| Kind of knowledge | Canonical place | When to touch it |
| --- | --- | --- |
| How one package works | README next to that package (path pattern in `PROJECT.md`) | Public API, config, storage, or hooks of that package change |
| Cross-package business capability | `docs/features/<slug>.md` (until it exists: the architecture page named in the INDEX) | Checkout, payments, pricing, ERP, shipping, tax, catalogue UX that spans packages |
| System map | `docs/architecture/*` | Integrations, markets, infra, or a capability's current mechanism changes |
| Why we chose X over Y | `docs/architecture/decisions/` | Irreversible or expensive choice |
| Traps, debugging paths, rejected approaches | `docs/notes/<slug>.md` (no row / cross-feature: `docs/notes/_general.md`) — **append-only** | A fix or investigation cost real time, or code contradicted docs or a ticket. See § Notes |
| Package list in the doc site | generated from READMEs | Do not duplicate README text into the doc site; link it |

Do **not** write a historical note per edit. No `docs/changes/` entry unless the user asks for a release note.
Update **current-state** docs so they still describe the code after the change.

Human doc-site pages keep the language in `PROJECT.md` § Docs language.
Agent-facing files stay in English.

## Always-on reading rule

1. Read `docs/features/INDEX.md`.
2. Open **only** the rows whose keywords, packages, or paths match the diff.
3. Deep-read those pages, the README of each touched package, `docs/notes/<slug>.md` for each matching row, and `docs/notes/_general.md` when they exist.
4. Do **not** read every package README. A full sweep is allowed only for a platform-wide decision (checkout contract, pricing, full-page cache, multi-market).
5. Do **not** open unrelated test trees unless this change set must update tests or the user asked.

## When tests are mandatory

Same change set as the production change. The command is in `PROJECT.md` § Environment.

- You changed a unit that already has a test → update that test.
- You added production code with branching, mapping, or money math → add a test for that unit.
- Price, tax, and ERP pricing math always get an explicit case.
- Skip copy-only, rename-only, and generated glue.

Do not claim a test passed when the command did not run. Integration suites stay on CI unless `PROJECT.md` says otherwise.

## When documentation is mandatory

Update docs in the **same change set** as the code when any of these change:

- customer-visible behaviour
- admin or shop config path or default
- HTTP, GraphQL, webhook, or extension contract
- payment, shipping, tax, or ERP payload
- cacheability or private content
- cron, queue, or worker assumptions

Skip docs for formatting, rename-only, tests that lock existing behaviour, copy, and generated files.

If you add a capability that is not a row in the INDEX, add the row.

## How to write a solution

- Describe the mechanism in 2–4 sentences from **this repo's code**. Name the package and the type that owns the behaviour.
- Grep before you cite a class, event, config path, table, column, or template token.
- Do not paste secrets, webhook signing secrets, or env-file values.
- Prefer “the app computes X on read via hook Y” over a ticket key. A tracker key may be a footnote, never the body.
- If the code does not do what a ticket claimed, document the code and say the ticket claim is unverified.

Templates: `docs/templates/feature.md`, `docs/templates/module-readme.md`, `docs/templates/adr.md`, `docs/templates/note.md`.

## Notes (append-only)

`docs/features/<slug>.md` says what the code does **now**. `docs/notes/<slug>.md` keeps what cost time and is not visible in the code. Append only. The slug is the INDEX row slug. No row, or a trap that spans features → `docs/notes/_general.md`. Notes are agent-facing, English, and not part of the human doc site.

Append a note in the same change set when:

- the cause took more than two attempts, or a reproduced bug had a non-obvious cause;
- hook or load order mattered;
- docs or a ticket contradicted the code;
- an approach was tried and abandoned.

No notes for typos, obvious fixes, or what the feature doc already says.

- Append at the **end** in the `docs/templates/note.md` format, at most about 6 lines. Cite type and method names, not line numbers. No secrets. Create `docs/notes/<slug>.md` only when the first entry is written.
- **Never** edit, reorder, reformat, or delete an existing entry. A wrong entry gets a new entry with `Supersedes: <date — title>`.
- If you remove a trap sentence from a feature doc, append it to the notes first.
- When a fix removes a trap, update the feature doc; the note stays as history.

## Delegation (Cursor only)

Claude Code skips this section. Cursor chats follow it.

The parent chat orchestrates. Multi-file implementation and unfamiliar areas go to worker subagents.

- When this chat is Claude Opus, you may read and search the repo for analysis and diagnosis. Delegate multi-file implementation to workers.
- For every worker, copy a model slug from this chat's subagent list. Use the newest Grok slug. Do not invent a slug.
- Do not pass `inherit` and do not omit `model` unless this chat is already that Grok.
- Opus, Claude, Sonnet, Fable, Composer, Gemini, and GPT are forbidden as workers unless the current user message names that model. If the list has no Grok slug, say so and do the work in this chat.
- Prefer the `implementer` subagent for code changes. If it is missing, use `generalPurpose` with that Grok slug.
- A worker may launch explore subagents on that same Grok slug. A worker does not launch another implementer.
- After a worker returns, open only the files it names. If the summary and the file disagree, resume that worker with the mismatch.

## Secrets

Never put credentials, API keys, or customer data into docs.
Database and production command rules in `PROJECT.md` § Environment still apply while you edit markdown.
