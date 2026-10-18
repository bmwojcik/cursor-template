# Catalogue and checkout capabilities

Behaviour that is **not** an external integration. Same writing rule: mechanism from this repo’s code, 2–4 sentences. Theme / app templates count as code.

When a heading outgrows a paragraph, add `docs/features/<slug>.md` and keep the heading here as the map.

## How to fill

1. Grep custom packages (code roots from `PROJECT.md`, theme / app overrides). Skip anything that only wraps an external API — that belongs on [Integrations](./integrations.md).
2. Keep the heading groups below. Rename them to this shop. Delete a group with no code.
3. Packages that exist in code but have no ticket still get **one sentence from the code**. Do not invent behaviour.
4. Cross-links to integrations (ERP price on a bundle parent, analytics events fired from the search template) stay as one bullet in **Dependencies**, not a second full story.

## Dependencies between capabilities (example — replace)

- A kit / bundle discount that an ERP must see: say whether the parent payload is empty and children carry the price — point at the ERP feature.
- A promotional line removed when a guest cart becomes a customer cart — point at both feature files.
- Checkout memory restores pickup-point attributes — name the cookie / metafield keys after you grep them.
- Search autocomplete does **not** emit the analytics event if the theme template does — point at [Integrations](./integrations.md).

## Placeholder headings (replace with real names)

### Bundle / kit configurator

Canonical: `docs/features/<slug>.md` when it exists.

How the set is selected (dynamic bundle vs static kit), where the set price is calculated (regular vs promotional child price), and which cart rules exclude the children. Grep the configurator template and the price plugin / hook.

### Gifts and cart-threshold promotions

Item-level vs cart-level discount. Threshold entity vs a generated sales rule. A second gift blocked where?

### Navigation, header, content hubs

Menu source (CMS vs module / section), empty-category hiding, cache tags. Do not paste a design-file URL as the mechanism.

### Search autocomplete and ranking

Which request container / query is used, which flags boost ranking, whether core autocomplete is disabled. Analytics events: here or on the integrations map?

### Checkout memory and guest-to-account merge

Last shipping / payment keys (cookies, metafields, customer attributes). What is restored (method + pickup point). What merge removes (promotional lines) and what it stores (totals before merge, qty on guest lines).

### Sales documents and tax display before address

Invoice vs receipt / tax-id flags if the code has them. Default postcode/region when prices are tax-exclusive and the address is still empty.

### Lowest-price / historical-price display

Which package stores the legally required low price, where it renders (PDP / listing), what job expires it.

### URL / canonical / hreflang

What is appended to `url_key` / handle, what is skipped for old products, where canonical / hreflang / robots live. Filter engines are not rewritten unless you grep a rewrite.

### Product stories and availability

Grouped “look” products, saleability flags that block add-to-cart, custom related-product links.

### Returns

Vendor returns package + the thin storefront layer (what replaces the default UI). One sentence if that is all the code is.

### Other packages (one sentence each, from code)

List leftover custom packages that are not integrations and do not deserve a feature file yet. Grep; one sentence; no ticket narrative.

In-store pickup that is a **carrier** talking to no external API may live here or on [Integrations](./integrations.md) — pick one map and point the other at it.
