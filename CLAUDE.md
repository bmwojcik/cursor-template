# CLAUDE.md

Guidance for Claude Code. Cursor does not read this file. Overview is appended from `PROJECT.md`.
The shared contract from `AGENTS.md` (documentation, tests, notes, quality bar, without its Cursor-only sections) is inlined below by the installer. Do not open `AGENTS.md`.

<!-- agents-contract -->

Project rules in `## Agent rules` and `## Claude` override this file where they conflict.

> **Reasoning doctrine:** for deep analysis or a hard bug, read `OPERATING_MANUAL.md` first, including the five-question self-test.
> **Code principles:** `CODING_PRINCIPLES.md`. Do not restate them here.

## Model routing

- Everyday work: the main chat, on the model the user chose.
- Deep analysis: Claude Opus, after reading `OPERATING_MANUAL.md`.
- Grok and Composer exist only in Cursor. Never name them as a model here.

## Delegation

The main chat orchestrates. Multi-file implementation and unfamiliar areas go to subagents through the Agent tool.

Whether the main chat may read and search the repository itself, or only orchestrates, is decided by this project's Agent rules.

- Implementation: the `implementer` subagent with `model: sonnet`. If it is missing, use a general-purpose subagent with `model: sonnet`.
- Read-only search across many files: the built-in `Explore` subagent. `sonnet` or `haiku` is acceptable there.
- A subagent does not see this chat. Give it the task, the files, and how to verify.
- A subagent does not launch another subagent.
- After a subagent returns, open only the files it names. If the summary and the file disagree, resume that subagent with the mismatch.

## Hard rules

The same rules as `.cursorrules` § 2 and § 0.1, which only Cursor reads.

- Database: read-only queries unless the user explicitly confirms a write.
- Production CLI: do not run install, upgrade, cache flush, reindex, or config writes. Suggest the command from `PROJECT.md` and wait.
- Do not edit vendored or upstream code. Never print secrets.
- Grep before you cite a type, event, config path, table, or column. Smallest viable diff. Do not claim a test passed when the command did not run.
- Stop and flag for a deeper model instead of guessing on pricing, totals, checkout, full-page cache, multi-market behaviour, hook ordering across packages, or irreversible data changes.
- Do not open `.cursorrules`, `.cursor/**`, `AGENTS.md`, or Cursor canvases unless the task is about them. When `PROJECT.md` says coding standards live in `.cursorrules`, grep that file for the relevant heading and read only that section.
- `var/review-change.*` are reviewer outputs; read only when the user asks about the review.
- Skills and rules written as `.cursor/skills/<name>` live at `.claude/skills/<name>` in Claude Code.

## Planning mode

When the user writes "PLAN": lay out 4–5 numbered steps, then stop after each step and wait for the literal command "proceed" before continuing.
