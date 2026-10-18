# Adapter: Shopify

**Stack** `shopify`. No PHPUnit skill is linked.

## Code roots

Theme:

```text
sections/
blocks/
snippets/
assets/
templates/
layout/
locales/
```

App or extension: `app/`, `extensions/`. Put the prefixes this repo actually owns into `PROJECT.md`.

docs-impact config:

```json
"module_folder_template": "",
"core_module_prefixes": []
```

Leave Magento module-folder guessing off.

## What to copy into the project

Append `adapters/shopify/CODING_PRINCIPLES.md` when the project has no Shopify section yet. Filled sketch: `adapters/shopify/PROJECT.example.md`.

Project-specific rules (laptop hook reminders, theme-push policy) stay in the project. Do not expect this template to link over them.

## Writing

2–4 sentences from this repo. Grep before citing a metafield, webhook topic, or route. No partner-dashboard tokens in docs.

Sibling apps are other git remotes. Cite the repository name, not a laptop path.
