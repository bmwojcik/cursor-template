# Git hooks

The project stores real stub files in `.githooks/`. The installer sets `git config core.hooksPath .githooks`. Stubs are copied from this repo's `hooks/` directory. They are not symlinks, so a commit still runs when the template checkout is missing — it logs one line and exits 0.

`hooks/is-local-dev.sh` is the laptop gate (Cursor, Claude Code, JetBrains, `.ddev`, `../bin/cli`, `.docs-impact.local`, `DOCS_IMPACT=1`). CI and `MAGE_MODE=production` no-op. If the file is absent, the other stubs still run.

## pre-commit

| Docs impact | Agent layer | Command |
| --- | --- | --- |
| `ci` | `committed` | `python3 docs/ci/docs-impact.py --staged` (blocks the commit) |
| `ci` | `local` | same script with `--staged --include-hidden-since-head` (advisory; feature docs stay hidden, `docs/ci/` stays committed) |
| `local` | either | linked `docs/scripts/docs-impact.py`, else `$CURSOR_TEMPLATE_HOME/tools/docs-impact.py`, with `--staged --include-hidden-since-head` (advisory) |
| `off` | either | skipped |

`--include-hidden-since-head` treats ignored files under `docs/` and ignored `README.md` files whose mtime is newer than HEAD as doc updates. Hidden docs are never staged, so without that flag a real edit would still look missing.

Advisory mode prints the findings and `docs-impact: advisory (Agent layer local) — update the hidden docs listed above`, then exits 0. It does not fail the commit. A notes violation still does. A missing script does not.

## post-commit

Runs when merge-reviewer is linked for this project and `.git/agent-tools.local` does not set **Merge reviewer** to `off`. The command is `python3 "$MERGE_REVIEWER_HOME/bin/post-commit-review"` with no flags. That process detaches and returns. A missing checkout prints one line and exits 0.

## Discovery

Hooks read `Stack`, `Agent layer`, and `Docs impact` from `.agent-tools/config.md`. If that file is missing they still read `PROJECT.md` and print `cursor-template: switches still in PROJECT.md — run install.sh --migrate-config`.

Post-commit runs the reviewer only when the checkout is linked and `.git/agent-tools.local` does not set `Merge reviewer` to `off`. A missing checkout prints one line and exits 0.

1. `CURSOR_TEMPLATE_HOME` / `MERGE_REVIEWER_HOME`
2. `<project>/tools/cursor-template` or `<project>/tools/merge-reviewer`
3. merge-reviewer only: `$(dirname "$CURSOR_TEMPLATE_HOME")/merge-reviewer`

## Version warning

Once per `(checkout, minimum)` pair, when `VERSION` is older than **Cursor template version**. The stamp is `.git/cursor-template-version-warned`.

## Do not

- Do not install these hooks from `composer install` or `npm install`. Production dependency install must stay a no-op. See `docs/scripts/composer-scripts.example.json`.
- Do not commit symlinks created by `install/link-project.sh`.
