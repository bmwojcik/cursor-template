---
name: reproduce-jira
description: >-
  Reads a pasted tracker issue, reproduces it on the local storefront or a
  shared preprod, creates a signed-in customer with Playwright when needed,
  places local orders and edits local customer, invoice, or product data when
  the ticket needs that state, applies the fix, and re-verifies in a short
  loop until the ticket behaviour is fixed or a stop condition hits. The
  parent delegates each phase to a subagent and keeps only a short brief. Use
  when the user pastes a Jira URL or issue key, or asks to reproduce,
  odtworzyć, zreprodukować, or zdiagnozować a ticket. Works in Cursor and
  Claude Code.
---

# Reproduce a tracker bug and fix it

Shop-specific values live in `PROJECT.md` § Reproduce ticket. Read that section before any phase. If a value is missing or still `REPLACE_ME`, stop and name the line to fill. Do not invent a URL, a Jira site, or a selector. Human setup: `docs/developer/reproduce-jira.md`.

The parent coordinates. It does not fetch the ticket, drive the browser, or edit code. Subagents do that. The user-facing report is in the user's language. Do not commit or push. Do not run the CLI named in `PROJECT.md` (setup, cache, indexer). When `PROJECT.md` **Merge reviewer** is `on`, do not launch that reviewer from this skill.

## Orchestrator

Memory is one file, `var/reproduce-jira/<ISSUEKEY>.md`. Overwrite it. Do not append transcripts, raw ticket JSON, Figma JSON, or screenshots. `var/` stays gitignored. Once a local customer exists, every overwrite keeps this block. The password is always `Repro1234!`. One block per website. Later overwrites keep every block that still has a confirmed account.

```markdown
## Customer
- email:
- password: Repro1234!
- role:
- website:
- store:
- order:
- invoice:
- product change:
```

**Cursor:** `Task`. Ticket, reproduce, implement, and verify use `subagent_type: generalPurpose`. Cause uses `explore`. Omit `model`. `run_in_background: false`. Never `resume: "self"`. Never set `environment: cloud`.

**Claude Code:** the Agent tool with the same split. If that tool is missing, run one phase yourself, write the brief, and read only that file on the next phase.

Launch independent phases in one message. After the ticket brief is on disk, start **reproduce** and **cause** together.

Each prompt is short: the issue key, this skill path, which section to follow, and "read `PROJECT.md` § Reproduce ticket and `var/reproduce-jira/<ISSUEKEY>.md`; return only a `## Return` block". Do not paste the ticket into the prompt. Fold the `## Return` block into the brief and drop the rest. Keep every confirmed `## Customer` block; the reproduce phase writes `## Customer` into the brief before submit, and its `## Return` repeats each email and `Repro1234!` so later overwrites keep those blocks. If the reply has no `## Return`, resume that same agent once and ask for only that block.

```markdown
## Return
- status: ok | blocked | failed
- facts: up to 8 one-line bullets
- paths: repo paths only
- next: one sentence
- email: one line per website when this phase registered a local customer; otherwise omit
- password: Repro1234! only together with those emails; otherwise omit this line
```

Stop without editing code when the bug was not reproduced, a phase is blocked, the same failure comes back, or the cause is pricing, totals, checkout payments, full-page cache, multi-store / markets, plugin order across 3+ packages, or a data patch. Say that implementation needs the deep-analysis manual named in `PROJECT.md` when that line is set.

Three code rounds maximum. Then report what is still wrong.

## 1. Ticket

Use the site and key prefix from `PROJECT.md`. If the paste points at the legacy site named there, say so and still try the current site.

Read the live issue. Do not invent the description from the key alone. Call only read tools: description, acceptance criteria, links, attachments, and **every comment**. Do not comment, transition, or edit the issue. Do not print connection secrets or API keys.

Discover each tool schema before calling it. Try readers in this order.

1. **Atlassian MCP** — namespace from `PROJECT.md` (usually `user-atlassian`). If `needsAuth`, call `mcp_auth`, then discover tools again. Read the issue with comments and attachments, and remote links when that tool exists. `cloudId` is the site hostname from `PROJECT.md`.

2. **Composio** — only when `PROJECT.md` sets the fallback to `yes` and Atlassian is missing, errored, or still unauthenticated. Search for one read of this issue with comments and attachments. Execute only slugs that search returned. Paginate comments until the page covers `total`. Download each image attachment and read the file. A filename is not a reproduction.

Stop and say the ticket body was not fetched only when every configured reader fails.

## 2. Figma and images

When the issue, a comment, or a remote link contains `figma.com`, or the issue has image attachments:

- **Figma MCP** — namespace from `PROJECT.md`. Read the linked node and download the frames you need to see. If the server is down or needs auth, say the design was not read.
- **Tracker screenshots:** open or download each image and read it.

Do not paste API tokens into the chat or the report.

## 3. Reproduce

Confirm the symptom in a browser, then confirm the cause against **this** working tree on the local storefront URL from `PROJECT.md`. Browse that URL. Do not run a local-dev CLI the project forbids.

| Environment | When | Secrets |
| --- | --- | --- |
| Local storefront | Default | URL from `PROJECT.md`. No basic auth unless that file says so. |
| Local admin | Admin-only bugs | Env file and key **names** from `PROJECT.md`. Never print values. |
| Preprod (or stage) | Ticket is data/env specific, or local cannot show the symptom | Shared env file and basic-auth key **names** from `PROJECT.md`. |

Browser is **Playwright MCP**. Namespace from `PROJECT.md` (usually `user-playwright`). Discover the schema, then use `browser_navigate`, `browser_snapshot`, `browser_fill_form`, `browser_click`, `browser_cookie_set`, `browser_take_screenshot`. Use another browser tool only when Playwright is absent, and say so.

Shop writes are allowed on the **local** storefront and **local** admin when the ticket needs that state. Do them in the browser. Do not write SQL.

- Register one local customer per website (section below) when the ticket needs that role.
- Place one or more orders for that customer when the ticket needs an order, a reorder, a shipment, or an invoice. Read the checkout page objects and the placing-order spec named in `PROJECT.md` before filling. Copy that flow. Prefer the offline payment that spec already uses. Do not open a live paywall.
- Edit that customer's account data and addresses, and that customer's invoices, through the storefront or local admin.
- Change product data (stock, status, price, attributes) on the local admin for the product under test. Record the previous value in `DANE.md` in the same section. If this reproduce phase returns blocked or failed, set it back in the local admin before you return. If it returns ok, leave the field changed. Reuse a product path already listed for that store when the ticket names none and a read-only SELECT still returns it. Orders, invoices, and product edits stay on the website where that customer and quote live.

Still forbidden: deleting accounts, admin configuration saves, cache flush, the CLI named in `PROJECT.md`, and any SQL other than the read-only command from `PROJECT.md`. Preprod and stage stay read-only: no new customers, no orders, no customer edits, no invoices, no product edits. There, log in with the preprod customer env from `PROJECT.md` when that file exists. If it does not, say the preprod login is missing.

If four attempts stall, stop and report the page, the blocker, and the next step.

### Two websites

A second store view of the same website is not a second website. Read **Websites** in `PROJECT.md` § Reproduce ticket. When that line lists two or more websites, storefront behaviour — cart, checkout, catalog, customer account, pricing, tax, shipping, payment — is reproduced on at least two of them. When the line is `none` or a single website, the default store code is enough.

Run the websites in this one reproduce phase, one after the other. Do not open two Playwright sessions at once.

One local customer per website. An account on one website cannot sign in on another. A tax id valid in one country is rejected in another; use the fixture row for that website, including a country prefix when the shop's validator requires it. The registration form on another website may omit a field that the first website has (for example phone).

Keep one `## Customer` block per website. Append one `DANE.md` section per website. If the second website is blocked, say so in `## Return` and still finish the first. One website is not a finished reproduction when `PROJECT.md` lists two or more.

### Local customer

Skip this block when the role is guest or `PROJECT.md` has no selector files.

Create a fresh local customer in Playwright, then stay logged in. Read selectors from the files named in `PROJECT.md`. Do not invent test ids.

1. Open the register path on the local storefront URL.
2. If a store-switch modal or cookie banner covers the form, dismiss it. Cookie names, when the project has them, are in the helper file named in `PROJECT.md`. Default store code is the one in `PROJECT.md` unless the ticket names another.
3. Fill the fields those page objects use. Email: `repro+<ISSUEKEY>+<timestamp>@` the repro domain from `PROJECT.md`. Password is always `Repro1234!`.
4. Business / B2B only when the ticket needs it and a fixture file is named: follow that file's row for this website (tax id and phone when the form has those fields). Do not reuse another website's tax id. A bare national number can fail when the field wants a country prefix.
5. Submit and wait for the success state the page object expects. If the login form is still showing, use the login path and the login selectors. Confirm the account page is signed in.

Write email, `Repro1234!`, the role, website, and store into `## Customer` in the brief **before** creating the account. If the success state the page object expects never shows, remove that `## Customer` block before you return. Later phases log in only when the block is still there. The plaintext stays `Repro1234!` in the brief and in the report. Do not delete the account.

### Ledger

`var/reproduce-jira/DANE.md` is the list a person opens instead of scrolling chats. `var/` stays gitignored. Append to this file. Do not overwrite it and do not commit it. A database refresh can remove the rows; the file is what remains. After a refresh, a failed login means that account is gone: register again on the local storefront and replace only that section.

Before creating the account, append the section below. If the success state the page object expects never shows, delete only that section and do not rewrite the rest of the file:

```markdown
## <ISSUEKEY> — <YYYY-MM-DD> — <website> / <store>
- email:
- password: Repro1234!
- role:
- website:
- store:
- address:
- product:
- order:
- invoice:
- product change:
```

Fill email, role, website, and store in that same section before submit. When this run already has an address id or a product URL, fill those lines (address id and city, product path). After an order, invoice, or product edit, fill those lines in the same section and in that website's `## Customer` block (order increment id, invoice id, product sku, the field, and the previous value). Read `DANE.md` first. Reuse a listed product path for that store only when the ticket names no product and a read-only SELECT still returns that product. Reuse an address id only when a read-only SELECT binds that row to the email in `## Customer`. Do not put admin passwords or basic-auth values in this file.

## 4. Cause

Grep before naming a class, event, config path, table, or column. Read `docs/features/INDEX.md` and only the rows that match, plus the README of each package you blame, plus `docs/notes/<slug>.md` of those rows and `docs/notes/_general.md` (known traps — check them before inventing a new theory). Copy patterns from the code roots in `PROJECT.md`.

The local storefront is the check of the cause. Preprod may be the only place the symptom shows. If local data cannot reproduce it, say that in `## Return`.

## 5. Fix loop

The implement subagent applies the smallest change that fixes the observed cause. Copy an existing class under the code roots. No drive-by refactors. Follow the repo's coding file (`CODING_PRINCIPLES.md` or `.cursorrules`).

Same change set:

- **Tests** — when `PROJECT.md` names a unit-test skill, read it and run the unit command it gives, scoped to the package you changed. Do not open unrelated test trees.
- **Docs** — read `.cursor/skills/update-feature-docs/SKILL.md` when behaviour, config, API, payment, shipping, tax, ERP, or cache changes. Skip a pure internal fix.
- **Static analysis** — the commands named in `PROJECT.md`, on the touched files.
- **Notes** — after `passed`, if the cause was non-obvious or took more than one round, append one entry to `docs/notes/<slug>.md` (no row: `_general.md`) per `AGENTS.md` § Notes, then `python3 docs/scripts/notes-append-only.py`. Never edit existing entries.

When `PROJECT.md` **Merge reviewer** is `on`, a later commit can start that reviewer (`docs/developer/review-change.md`). Leave the tree ready for that. This skill does not commit and does not start the reviewer. When the switch is `off`, there is no reviewer step.

The verify subagent repeats only the reproduction steps on the local storefront and reports pass or the one new failure. When `## Customer` is in the brief, those steps use the existing account on that website: sign in on the login path from `PROJECT.md` with that email and `Repro1234!` and the login selectors named there, and do not submit registration again. On `failed`, leave a recorded product change in place and a new implement subagent gets the brief file plus that one sentence. On pass, if `product change` names a field, set it back to the recorded value in the local admin before you return. It does not get the ticket again. When `PROJECT.md` lists two or more websites, verify the symptom on each website that the reproduce phase reached.

If the storefront cannot show the fix until cache is flushed, put the exact command from `PROJECT.md` in `## Return` and stop. Do not run it yourself.

## Report

The parent writes this from the brief file. No phase transcripts.

```markdown
## Ticket
<key, one sentence of expected vs actual. Link.>

## Reproduction
- Environment, role, and each website/store. Created email and password `Repro1234!` per website when you registered one. Do not print admin or basic-auth secrets.
- Result per website: reproduced / not reproduced / blocked
- Dane: `var/reproduce-jira/DANE.md`

## Cause
<package> — <symbol> (verified on the local storefront / not verified)

## Fix
- Round <1-3>: paths changed
- Verification: pass / still failing (one sentence)
- Tests: command and result
- Docs: updated / no contract change
- Notes: appended to `docs/notes/<slug>.md` / nothing tricky
- Not committed. When merge-reviewer is enabled, the next commit can start it.
```
