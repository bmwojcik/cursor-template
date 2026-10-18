# Adapter: Magento 2

**Stack** `magento2`. The installer links `adapters/magento2/rules/phpunit.mdc` and `adapters/magento2/skills/write-phpunit`. Other projects do not get those links.

## Code roots

```text
app/code/<Vendor>/
app/design/frontend/<Vendor>/<theme>/
```

docs-impact config for this stack:

```json
"module_folder_template": "app/code/{vendor}/{name}/",
"core_module_prefixes": ["Magento_"]
```

The installer sets those when it writes a missing config.

## What to copy into the project (real files, not links)

Append, do not overwrite:

- `adapters/magento2/CODING_PRINCIPLES.md`
- `adapters/magento2/cursorrules.md`

Filled sketch: `adapters/magento2/PROJECT.example.md`.

## Local mode extras

`adapters/magento2/agent-layer.exclude` hides new module and theme READMEs. Tracked READMEs still show in `git status`.

## Commands

Use the wrapper named in `PROJECT.md`. Do not run setup, cache, or indexer commands unless the human asked. Unit tests: **Test paths** and the write-phpunit skill. Do not open `dev/tests/` or `vendor/**/Test` for everyday work.

Grep this repo before citing a class, event, config path, or table. Core and marketplace modules often differ from a vanilla install.
