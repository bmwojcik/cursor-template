# How to fill the architecture maps

These pages are **maps**, not feature write-ups. An implementing agent replaces every placeholder with mechanism from **this** repository. Do not copy another shop’s integrations, website ids, or host inventory.

## Before you write

1. Read [`docs/features/INDEX.md`](../features/INDEX.md). Architecture headings are the map; a `docs/features/<slug>.md` row (when it exists) is the canonical page.
2. Detect the platform (`PROJECT.md`: Magento 2, Shopify, other) and the custom-code roots.
3. **Grep** before you cite a class, event, config path, table, metafield, column, or package name. Platform-default memory is unreliable here.
4. Open lockfiles for names and versions (`composer.lock`, `package-lock.json`, theme lockfile). Do not invent a version.

## Writing rule

- **2–4 sentences** of current mechanism per heading: owning package + class/module/hook.
- Prefer “the app computes X on read via plugin/hook Y” over a tracker key. A ticket may be a footnote, never the body.
- When a heading outgrows one short paragraph (cross-package contract, many config paths, an API payload), add [`docs/features/<slug>.md`](../templates/feature.md), add/fix the INDEX row, and leave this architecture heading as a pointer (“canonical: …”).
- If a ticket or old README disagrees with the code, document the code and say the ticket claim is unverified.

## Which page owns what

| Page | Fill with |
| --- | --- |
| [`index.md`](./index.md) | Nav only. Do not dump mechanism here. |
| [`technologies.md`](./technologies.md) | Runtime, storefront, search, cache — names from lockfiles. |
| [`infrastructure.md`](./infrastructure.md) | Environment **shape** (edge → app → data). No IPs, ticket URLs, account ids. |
| [`integrations.md`](./integrations.md) | How this app talks to **other systems**. Heading + 2–4 sentences, or a feature pointer. |
| [`capabilities.md`](./capabilities.md) | Catalogue / checkout that is **not** an external system. |
| [`markets.md`](./markets.md) | Websites / markets / currencies / tax display / payment and shipping sets. Carts are not shared unless the code says they are. |
| [`decisions/`](./decisions/index.md) | Why X instead of Y. Copy [`docs/templates/adr.md`](../templates/adr.md). |

## INDEX pointers

- New capability → add a row. *Canonical page* is the feature file if it exists; otherwise the architecture heading.
- Do not paste mechanism into the INDEX table.
- Delete pack examples (`example-payment-split`, `Acme_*`) after the first real feature file exists. Never leave fictional names on a live shop.

## Forbidden on these pages

- Secrets, API keys, webhook signing secrets, DSNs, env-file values, customer PII
- Public or private IPs, VIP/local addresses, panel ticket URLs, cloud account ids
- Laptop paths, agency names, or another shop’s brand / module / website ids
- A changelog or “what we did last week”

## Stop

Do not backfill every package README. Do not create `docs/changes/` unless someone asked for a release note. After a coherent behaviour/config/API change, run `python3 docs/scripts/docs-impact.py --staged`.
