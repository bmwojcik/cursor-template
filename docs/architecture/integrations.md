# Integrations

How **this** application talks to other systems. Write the mechanism from code (2–4 sentences each). No secrets.

Custom packages + vendor packages that this repo actually depends on. Grep custom-code roots from `PROJECT.md`, plus the lockfile, before you add a heading.

When a section grows past a heading plus a short paragraph, add `docs/features/<slug>.md`, point [INDEX](../features/INDEX.md) at it, and keep this page as the map.

## Heading pattern (keep, rename)

Use these **groups**. Delete a group that this shop does not have. Add a group only when code talks to a new kind of system.

1. **Dependencies between integrations** — one bullet each, with an INDEX / feature pointer. Cross-payload facts only (what system A reads that system B wrote).
2. **ERP and orders** — one `###` heading per ERP / accounting bridge.
3. **Payments** — one `###` heading per gateway or paywall.
4. **Delivery and fulfillment** — carriers, pickup points, marketplace inbound/outbound.
5. **Marketing, analytics, content** — tag manager, CDP, product feed, SMTP. Omit a name that is not in the lockfile or custom-code roots.
6. **B2B registration and taxes** — tax-id registries, customer-group mapping.
7. **Related (not an external integration)** — one sentence + link to [Capabilities](./capabilities.md).

Each `###` heading:

- First line: “Canonical: [slug](../features/<slug>.md)” if that file exists; otherwise the heading **is** the map.
- Then 2–4 sentences: push vs pull, owning package + class, what is stored vs computed on read.
- No API keys, webhook secrets, merchant / account display names, configuration-collection ids.

The four blocks below are **fictional**. They match the example INDEX rows. Replace each heading with a real system from this repo, rewrite the sentences from that code, then delete leftover `Acme_*` / `example-*` names. Delete [`docs/features/example-payment-split.md`](../features/example-payment-split.md) when the first real feature file exists.

## Dependencies between integrations (example — replace)

- The ERP reads a pickup-point id written by the carrier package — [example-shipping-zones](../features/INDEX.md) until a real feature file exists.
- A surcharge line the ERP expects is the sum of fee + fee-tax columns — point at the ERP feature when it exists.
- Amount captured is taken from the payment record, not from the order paid total, when the code does that — point at the payment feature.

## Example payment gateway

Canonical while the pack example exists: [`example-payment-split`](../features/example-payment-split.md).

The shopper sees each wallet as its own checkout tile. Capture still goes through one merchant account. `Acme_PaymentSplit` turns the vendor element into tiles when `payments/split_wallets/enabled` is on. On submit a hook writes the vendor’s capture code onto the cart.

Replace this heading with the real gateway package names from this repo (grep the payment method codes). One heading per gateway. A market-specific split belongs in [Markets](./markets.md) as a pointer, not a second story.

## Example ERP

See [INDEX — example-erp-orders](../features/INDEX.md) (map until a feature file exists).

The ERP **pulls** or **receives** orders through this shop’s HTTP API (Admin / Storefront / REST — grep which). This repo extends the order payload (extension attributes, metafields, or Admin API fields). The platform does **not** push unless you grep a publisher / queue consumer that does. Name the builder class that computes export pricing **on read** if that is what the code does. Say what is persisted (document numbers on the order) vs computed (`export_pricing` on get/list).

## Example tax ID lookup

See [INDEX — example-tax-id](../features/INDEX.md).

A validator checks format, then calls an external registry. Success sets a flag on the customer / cart / order and may map a customer group. Failure on login may drop the group. Credentials stay in environment config.

## Example shipping

See [INDEX — example-shipping-zones](../features/INDEX.md).

Carriers and pickup-point widgets live in their own packages. A shared delivery module may remap postcodes to rate zones so prices are not frozen per store view / market. Name the mapper class and which country/postcode families it handles — after you grep them. Pickup-point ids that the ERP reads belong in the dependency bullets above.

## Observability (only if custom code talks to it)

Name the error-tracker **package** and whether a filter drops known noisy messages. No DSN. Edge / WAF presence belongs on [Infrastructure](./infrastructure.md) unless this repo has a client module.
