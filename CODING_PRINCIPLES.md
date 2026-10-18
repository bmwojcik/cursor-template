# Coding principles

Shared by Cursor and Claude Code. One list. Do not copy it into `CLAUDE.md` or `.cursorrules`.
Stack-specific rules live in `adapters/<stack>/CODING_PRINCIPLES.md` and are copied into a project when that stack needs them. Machine-checked style stays in the project's linters, named in `PROJECT.md`.

## Names and comments

- Names carry the meaning. Do not narrate the method in a comment.
- No commented-out code.
- A comment is only for a constraint the code cannot show (a protocol limit, a compiler bug, a required call order).
- Where the language has doc comments, keep parameter and return tags only. No prose that restates the signature. Add a throws tag only when that exception is the contract.
- No author, package, or category tags on new code.

## Shape

- Smallest viable diff. No drive-by refactors.
- Constructor or explicit injection. Do not reach for a service locator at runtime.
- Extend upstream code from this repository. Do not edit vendored copies.
- Log through the project's logger. No print-debugging left in the diff.
- New names: no underscore prefix, no abbreviations, no Hungarian notation.

## Defensive

Assume config, cache, and records are only partly there.

- A missing config value is normal. Default it and cast.
- Do not read an array key that may be absent without a presence check.
- Optional attributes may be null, empty, or the string `0`.
- A missing record is a normal path. Handle it or let the caller see the failure. Do not swallow it.
- Guest and empty-cart flows are normal. Do not assume a hard-coded market, website, or currency id.
- User-facing money goes through the project's formatter. Do not format ad hoc in a template.
- Customer-specific HTML is private under a full-page cache. Do not put it in a public cache entry.

## Hot paths

- Do not load a record inside a loop. Batch, then index by id.
- Do not start a second query per item of the first. Join or batch.
- Select the columns you need.
- Cache computed values that are safe to share. Tag them so they can be dropped. Do not cache one customer's HTML as if it were public.
- Do not flush the whole cache from application code.
- Do not hook a function that runs on every attribute read. Prefer a hook that can stop the original only when you must replace it.
- Hooks on request-wide events stay cheap. I/O belongs in a queue.

## Tests

- Same change set as the production code. See `AGENTS.md` § When tests are mandatory.
- One test type per production type. Cases are table rows, not a file per case.
- Do not weaken a test to make production pass. Change the code, or change the test in the same change set when the contract change is intentional.
- The command is the one in `PROJECT.md`. Do not invent a second test runner.
