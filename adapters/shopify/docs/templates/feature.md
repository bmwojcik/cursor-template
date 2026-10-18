# Feature name

One sentence: what the shopper or the storefront gets from this.

## How it works

2–4 sentences from **this** theme. Name the section, block, or snippet and the Liquid or asset script that owns the behaviour. Not a ticket list.

## Pieces

| Piece | Role |
| --- | --- |
| `sections/<name>.liquid` | page or theme section |
| `blocks/<name>.liquid` | block inside that section |
| `snippets/<name>.liquid` | shared markup |

## Configuration

Setting ids from the `{% schema %}` and the default when the merchant leaves them unset. No secrets.

## Contract (if any)

Metafields, app blocks, or routes another system reads.

## Deliberately does not

Things the theme does not render, even if a ticket suggested otherwise.

## Index

Add or fix the row in [`docs/features/INDEX.md`](../features/INDEX.md).
