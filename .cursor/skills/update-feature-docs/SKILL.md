---
name: update-feature-docs
description: Updates current-state docs (package README, feature page, architecture, ADR, INDEX) after a behaviour, config, API, payment, shipping, tax, ERP, or cache change. Use when finishing a coherent code change, adding a package, or when the user asks to document a feature.
---

# Update feature docs

Follow `AGENTS.md`. Templates: `docs/templates/feature.md`, `docs/templates/module-readme.md`, `docs/templates/adr.md`.

## Workflow

1. **Diff.** List changed paths under the code roots in `PROJECT.md` (and the docs-impact config when Docs impact is not `off`: `docs/ci/docs-impact.config.json` or `docs/scripts/docs-impact.config.json`), plus `docs/`, and third-party packages only if this repo patches them.
2. **INDEX.** Read `docs/features/INDEX.md`. Collect matching rows (keywords, packages, paths).
3. **Choose the owner** (do not write the same story in three places):
   - One package's hooks/config/tables → that README
   - Behaviour spanning 2+ packages → `docs/features/<slug>.md`; if the file does not exist yet, update the architecture page named in the INDEX and add/adjust the INDEX row
   - New irreversible choice (checkout contract, pricing, full-page cache, multi-store/markets) → new ADR from `docs/templates/adr.md`
   - Integration payload / market / infra map → `docs/architecture/integrations.md` (or `markets.md` / `infrastructure.md`)
4. **Write current state**, not history:
   - 2–4 sentences of mechanism from **this** code (package + class/module names)
   - Grep before citing a class, event, config path, table, metafield, or column
   - No secrets, no sandbox keys, no env-file values
   - Tracker keys optional at the end; never as the only content
   - If a ticket disagrees with the code, document the code
   - Do not drop a trap sentence from a feature doc without appending it to the notes first
5. **Notes (append-only).** If this change set hit a trap, a non-obvious cause, an ordering issue, a rejected approach, or code contradicting docs/ticket (`AGENTS.md` § Notes), append one entry at the end of `docs/notes/<slug>.md` (no row: `docs/notes/_general.md`) in the `docs/templates/note.md` format. Never edit existing entries. Run `python3 docs/scripts/notes-append-only.py` until it prints `ok`. Skip when nothing was tricky.
6. **INDEX.** Add or edit the row when you created a feature file, renamed a package, or moved the canonical page.
7. **Docs impact.** Read `PROJECT.md` **Docs impact**. `off` → skip this step. `ci` → `python3 docs/ci/docs-impact.py --staged`. `local` → `python3 docs/scripts/docs-impact.py --staged`. Fix findings in this change set. Do not skip the check for a behaviour, config, or contract change when the switch is not `off`.
8. **Stop.** Do not backfill unrelated README files. Do not add `docs/changes/` unless the user asked for a release note.

## Checks before you finish

- [ ] A reader can explain the new behaviour without opening a ticket tracker
- [ ] Cited names exist in the repo (grep)
- [ ] No credentials
- [ ] Human doc-site language is unchanged unless the user asked
- [ ] Docs-impact is clean when `PROJECT.md` **Docs impact** is not `off` (command in step 7)
- [ ] `python3 docs/scripts/notes-append-only.py` prints `ok` (existing notes untouched)
