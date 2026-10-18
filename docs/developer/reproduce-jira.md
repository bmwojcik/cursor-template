# Reproduce a ticket and fix it

Skill: [`.cursor/skills/reproduce-jira/SKILL.md`](../../.cursor/skills/reproduce-jira/SKILL.md).

Paste a tracker URL or issue key in a **new** agent chat. The skill reads the issue, comments, and attached images, reproduces the bug on the local storefront (or preprod when the ticket is environment-specific), applies a fix, and checks the storefront again. Up to three code rounds. It does **not** commit. When `PROJECT.md` has **Merge reviewer** `on`, the next commit can start that reviewer ([setup](./review-change.md)). When the switch is `off`, there is no review step.

Start the message with `@reproduce-jira` when you want to be sure the skill loads. A bare key such as `ABC-123` is usually enough. A bug description with no key and no `@` may not start it.

Cursor and Claude Code share this file. Claude Code also needs the MCP servers below in **its** session. An empty MCP list stops the skill at “ticket body was not fetched”.

## Before the first run

Copy [`PROJECT.example.md`](../../PROJECT.example.md) to `PROJECT.md` and fill **Reproduce ticket**. Every `REPLACE_ME` in that section blocks the skill. The skill will name the line; it will not guess a URL.

Never put passwords, tokens, or basic-auth values in `PROJECT.md`. Only file paths and **key names**.

| You need | Where it is configured |
| --- | --- |
| Jira site and issue prefix | `PROJECT.md` — site, key prefix |
| Local storefront URL | `PROJECT.md` — local URL. The skill browses it. It does not run a forbidden local-dev CLI. |
| Admin and preprod login | Env files named in `PROJECT.md`. The agent reads them and does not print the values. |
| Signed-in customer | Playwright registration on the local storefront only. Password is always `Repro1234!`. One account per website when **Websites** in `PROJECT.md` lists more than one — accounts are not shared. The running brief is `var/reproduce-jira/<KEY>.md`. Accounts, that password, addresses, products, orders, and invoices are appended to `var/reproduce-jira/DANE.md` (gitignored, not committed), one section per website. A failed registration removes that brief block and only that ledger section. Later phases sign in with the existing account. No new accounts on preprod. |
| Design frames | Figma MCP namespace in `PROJECT.md`, only when the ticket links `figma.com` or has screenshots. |

MCP servers the skill calls, in order: Atlassian (then Composio only if `PROJECT.md` says `yes`), Figma when a design is linked, Playwright for the browser. Discover each tool schema before calling it.

Reload the editor window after adding the skill so a new chat sees it. Magento, Docker, and the shop do not need a restart.

## What a new person should read

This pack is a documentation and review schema, not a shop. Read this slice, then only the rows a task touches.

| Question | Page |
| --- | --- |
| Where does knowledge live, and when must docs change? | [`AGENTS.md`](../../AGENTS.md) |
| How do I edit docs without starting a second system? | [`docs/how-to-edit.md`](../how-to-edit.md) |
| Which feature pages exist? | [`docs/features/INDEX.md`](../features/INDEX.md) — open matching rows only |
| How do I land this pack on a new repo? | [`IMPLEMENT.md`](../../IMPLEMENT.md) and [`NEW-PROJECT-PROMPT.md`](../../NEW-PROJECT-PROMPT.md) |
| Magento or Shopify path names | [`adapters/magento2.md`](../../adapters/magento2.md) or [`adapters/shopify.md`](../../adapters/shopify.md) |
| Shop URLs, env key names, test command | `PROJECT.md` (from [`PROJECT.example.md`](../../PROJECT.example.md)) |
| What runs after I commit? | [`docs/developer/review-change.md`](./review-change.md) |
| How should a feature page or a module README look? | [`docs/templates/`](../templates/feature.md) |

Coding rules stay in the target repo (`.cursorrules`, `CODING_PRINCIPLES.md`). This skill does not restate them. The fix it writes has to satisfy that file, the unit-test skill named in `PROJECT.md`, and `update-feature-docs` when behaviour or a contract changes — so the post-commit reviewer and the test run have something to check.

## How the agent spends context

The parent chat only sequences work. Ticket text, screenshots, and file dumps stay in subagents. Between phases the parent keeps `var/reproduce-jira/<KEY>.md` (gitignored): a short `## Return` block, overwritten, not a transcript.

After the ticket brief is saved, reproduction and cause-finding start together. A failed verification sends the next code round one sentence about what is still wrong, not the ticket again.

The loop stops without a guess when the bug was not reproduced, the same failure repeats, or the cause is pricing, checkout payment, full-page cache, multi-store, plugin order across several packages, or a data patch.

Storefront behaviour (cart, checkout, catalog, account, price, tax, shipping, payment) is reproduced on at least two websites when `PROJECT.md` lists them. Two store views of one website do not count. One Playwright session, websites one after another.

## After it finishes

The report names the cause, the paths it changed, the test command result, and whether docs were updated. The tree is dirty on purpose. Commit when you want the reviewer. Do not expect this skill to open a merge request.
