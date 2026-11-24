# Acme Theme — guidance

## Overview

Acme Theme is a Shopify theme. Apps that share a contract live in other repositories.

## Stack

Shopify theme. Sections, blocks, and snippets are the units of change.

## Code roots

```text
sections/
blocks/
snippets/
assets/
templates/
layout/
locales/
```

## Package naming

- **Module form:** section, block, or snippet file name
- **Theme or app roots:** `sections/`, `blocks/`, `snippets/`

## Environment

```bash
npm test
shopify theme check
```

Do not commit merchant settings data. Do not run a theme push unless the user asks.

## Docs language

- **Human docs:** English
- **Agent docs:** English

## Quality bar

- No secrets in the diff.
- Do not commit merchant-edited settings.
- A theme base, app, or API version change ships with the `upgrade-dependency` consumer table; a template, section, or setting that references a removed snippet, block, setting id, or app block handle is blocking.

## Agent rules

### Theme

Sibling apps are other git remotes. Cite them by name, not by a laptop path.
