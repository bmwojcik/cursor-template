# Feature index

Entry point for agents and reviewers. **Always read this file**, then only the rows that match the diff.

`docs/scripts/docs-impact.py` maps a diff onto these rows. The *Packages* and *Keywords / paths* columns must point at real paths in **this** repository.

*Canonical page*: if `docs/features/<slug>.md` exists, **that file is the source**. Otherwise the heading in `docs/architecture/` is the map. Do not copy mechanism into this table — pointers only.

New feature page: [`docs/templates/feature.md`](../templates/feature.md). Contract: [`AGENTS.md`](../../AGENTS.md).

Traps and debugging paths (agent-facing, **append-only**): `docs/notes/<slug>.md` with the same slug as the row below; cross-feature ones in `docs/notes/_general.md`. Feature pages describe the current state and may be edited; notes never are — see `AGENTS.md` § Notes.

When you add `docs/features/<slug>.md`, point *Canonical page* at that file and keep the architecture link as “map”.

Replace the example rows below with real capabilities from this repo. Delete the `example-payment-split` row after the first real feature file exists.

| Slug | Canonical page | Packages | Keywords / paths |
| --- | --- | --- | --- |
| example-payment-split | [example-payment-split](./example-payment-split.md) ([map](../architecture/integrations.md#example-payment-gateway)) | `Acme_PaymentSplit`, `Vendor_Payments` | `split_wallets`, `RewriteMethodOnSubmit`, `wallet_codes` |
| example-erp-orders | [Integrations — ERP](../architecture/integrations.md#example-erp) | `Acme_Erp` | Admin API orders, `export_pricing`, order export |
| example-tax-id | [Integrations — tax ID](../architecture/integrations.md#example-tax-id-lookup) | `Acme_TaxId` | VAT lookup, customer group mapping |
| example-shipping-zones | [Integrations — shipping](../architecture/integrations.md#example-shipping) | `Acme_Delivery` | postcode mapper, carrier pickup point |
| markets | [Markets](../architecture/markets.md) | — | websites, markets, currencies, payment sets |
| review-change | [Merge reviewer (optional)](../developer/review-change.md) | — | `Merge reviewer`, `merge-reviewer`, `bin/post-commit-review`, `.githooks/post-commit` |
