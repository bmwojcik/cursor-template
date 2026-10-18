# CLAUDE.md

Guidance for Claude Code. Follow `AGENTS.md`. Overview and commands for this repository are appended from `PROJECT.md`.

> **Reasoning doctrine:** for deep analysis or a hard bug, read `OPERATING_MANUAL.md` first, including the five-question self-test.
> Everyday work uses Composer. Deep analysis uses Claude Opus.
> **Code principles:** `CODING_PRINCIPLES.md`. Do not restate them here.

## Model routing

- Everyday implementation: Composer.
- Deep analysis: Claude Opus, after reading `OPERATING_MANUAL.md`.
- When this chat delegates implementation, workers use the newest Grok slug. See `AGENTS.md` § Delegation.

## Planning mode

When the user writes "PLAN": lay out 4–5 numbered steps, then stop after each step and wait for the literal command "proceed" before continuing.
