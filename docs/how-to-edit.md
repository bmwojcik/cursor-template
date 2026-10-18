# How to edit documentation

Documentation describes the **current** system. Update it in the same change as the code when behaviour, config, or a contract changes.

Human pages keep the language in `PROJECT.md`. Agent-facing files stay in English.

## While developing

1. Start from [`docs/features/INDEX.md`](./features/INDEX.md). Open only matching rows.
2. Update the owner: package README, `docs/features/<slug>.md`, or the architecture map. See [`AGENTS.md`](../AGENTS.md).
3. When `PROJECT.md` **Docs impact** is not `off`, run the matching command (`docs/ci/docs-impact.py` or `docs/scripts/docs-impact.py`, `--staged`).
4. Put docs in the same commit as the code.
5. When **Merge reviewer** is `on`, the next commit can start it. Do not review in the chat that wrote the code.

Skip docs for formatting, rename-only, tests that lock existing behaviour, and generated files.

## Ownership

| Kind | Place |
| --- | --- |
| One package | README next to the package |
| Cross-package capability | `docs/features/<slug>.md` |
| System map | `docs/architecture/*` |
| Why X not Y | `docs/architecture/decisions/` |
| Trap, rejected approach | `docs/notes/<slug>.md` (append-only) |
| Optional reviewer | [`docs/developer/review-change.md`](./developer/review-change.md) |

## Notes

Append at the end. Never edit an old entry. `python3 docs/scripts/notes-append-only.py` must print `ok`.

## Hooks

Laptop hooks live in `.githooks/` and run only when `is-local-dev.sh` says this is a laptop (or when that file is absent, they still run). A missing template or reviewer checkout does not fail the commit.

- **pre-commit:** docs-impact when the switch is `ci` or `local`, then the notes check.
- **post-commit:** merge-reviewer only when the switch is `on`.

Install with `install/install.sh` from the cursor-template checkout. Do not install hooks from production dependency install.

Skip docs-impact once: `DOCS_IMPACT_SKIP=1` or `[skip docs-impact]` in the subject. Skip review: `REVIEW_CHANGE=0` or `[skip review]`.
