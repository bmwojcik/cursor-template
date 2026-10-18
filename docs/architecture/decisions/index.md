# Architecture decisions (ADR)

Record **why** X was chosen instead of Y. This is not a review procedure and not a changelog.

Template: [`docs/templates/adr.md`](../../templates/adr.md).

Reading every package README is allowed only for a **platform-wide** ADR (checkout contract, pricing, full-page cache, multi-store / markets). Day to day, reviewers read [`docs/features/INDEX.md`](../../features/INDEX.md) and the narrow subset that matches the diff.

## How to add one

1. Copy the template to `docs/architecture/decisions/ADR-0001-short-slug.md` (next free number, kebab-case slug).
2. Fill Context / Decision / Consequences / Rejected alternatives from **this** repo’s constraints (theme, cache, markets, ERP), not from a ticket title.
3. Link the INDEX row a reviewer must open.
4. Status starts as `proposed`. Flip to `accepted` when the choice is in the code. `superseded` points at the newer ADR.

No accepted ADRs yet. Do not invent an ADR for a routine feature; use a feature page.
