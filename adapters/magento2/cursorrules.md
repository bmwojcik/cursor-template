# .cursorrules fragment — Magento 2

Append to the project's `.cursorrules` when **Stack** is `magento2`. Do not overwrite rules the project already has.

## Hard rules

- **Read-only SQL** unless the user confirms a write. Use the database command named in `PROJECT.md`.
- **Do not run Magento CLI** (`setup:*`, `cache:flush`, `indexer:reindex`, `config:set`) unless the user asks. Suggest the command and wait.
- **Do not edit** `vendor/magento/*`, `vendor/hyva-themes/*`, or `lib/internal/Magento/*`. Prefer a plugin, preference, observer, or theme override.
- **No `ObjectManager` at runtime.** See `adapters/magento2/CODING_PRINCIPLES.md`.
- **Container wrapper:** use the command prefix in `PROJECT.md` (**Forbidden local CLI** names the ones this shop does not use). Do not switch the project to a different container tool.

## Verify

After PHP edits, run the static-analysis commands in `PROJECT.md` when they exist. Scope them to the files you touched.

## Tests

Follow `.cursor/rules/phpunit.mdc` and `.cursor/skills/write-phpunit/SKILL.md`. The unit command is **Test paths** in `PROJECT.md`. Do not add PHPUnit to the blocking pre-commit hook.

## Escalate

Flag a deeper model instead of guessing when the change touches store-scoped prices, tax, full-page cache, multi-website behaviour, plugin order across three or more modules, or a data patch.
