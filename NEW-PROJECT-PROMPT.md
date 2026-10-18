# Prompt: land cursor-template on a repository

Human copy-paste. The agent follows [`IMPLEMENT.md`](./IMPLEMENT.md).

Everyday coding: Composer 2.5 Fast. Deep analysis: Claude Opus with `OPERATING_MANUAL.md`. Cursor workers: the newest Grok slug. The reviewer, when enabled, is [merge-reviewer](https://github.com/bmwojcik/merge-reviewer), not this chat.

## Before you paste

1. Open the target repository as the workspace.
2. Have this template on disk (sibling checkout or an `@` attach). Do not copy `docs/features/example-*.md` into the live repo.
3. New Agent chat. Attach this pack and paste the block for **new** or **existing**.

## New project

```text
You are landing cursor-template onto THIS repository. Read IMPLEMENT.md and follow it. Do not invent a second docs system. Do not copy another shop's modules, agency names, or laptop paths.

Ask me these three questions first and wait for the answers before you write files:
1. Agent layer: committed or local?
2. Reviewer on this laptop: yes or no?
3. Docs impact: ci, local, or off?

Then:
- Detect the stack (magento2, shopify, or generic) and read adapters/<stack>/.
- Write PROJECT.md from PROJECT.example.md: overview, stack prose, code roots, environment commands, docs language, quality bar, agent rules. No tool switches.
- Write .agent-tools/config.md from .agent-tools/config.example.md with the three answers, git host, test command, and base branch.
- If I said no to the reviewer, run install.sh with --without-reviewer. If I said yes, run install.sh and tell me only if the reviewer checkout is missing.
- Seed docs/features/INDEX.md, docs/notes, and docs/architecture from THIS code. Mechanism in 2–4 sentences. Grep before you cite a type, event, config path, table, or column. No secrets.
- Run install.sh --check.

Work until the IMPLEMENT.md checklist is honest. If you cannot prove a system from this repo, omit it.
```

## Existing project (migration)

```text
You are migrating THIS repository onto cursor-template. Read IMPLEMENT.md. Do not delete anything until the checks at the end pass.

Ask me these three questions first and wait:
1. Agent layer: committed or local?
2. Reviewer on this laptop: yes or no?
3. Docs impact: ci, local, or off?

Then compare every local copy with the tool repos (cursor-template, and merge-reviewer when I said yes):
skills, rules, agents, commands, docs scripts, templates, hooks, AGENTS.md, CLAUDE.md.

- Move project-specific instructions into PROJECT.md ## Agent rules, ## Quality bar, and ## Environment. Tool switches and ## Reproduce ticket go to .agent-tools/config.md (`install.sh --migrate-config` does this move).
- `install.sh --check` prints `team-ref-to-local <file>:<line> <path>` when a committed file mentions a laptop-only link (a skill, a linked rule, `docs/templates` when it is linked, or a linked notes/docs-impact script). Fix those lines before you finish. A hit inside a `docs/notes/*.md` entry is `team-ref-in-history` and stays; notes are append-only. Local agent layer skips the scan. The warning does not by itself fail `--check`.
- In a committed layer, `OPERATING_MANUAL.md` is a real file. `.agent-tools/vendored.lock` records the sha256 that was copied. Do not hand-edit that file unless you mean to: `--check` then prints `vendored-modified` and stops. `install.sh --sync-vendored` overwrites it after a backup under `.git/cursor-template-backup/`.
- If CI runs docs/scripts/docs-impact.py (or a pipeline step that calls it), move that script and its config to docs/ci/ and point the job at docs/ci/docs-impact.py. The same job runs `python3 docs/ci/notes-append-only.py --base <ref>`. Do not delete a CI-owned script.
- A committed human doc page that the template would link (for example `docs/developer/review-change.md` or `docs/templates`) stays in git. Add that path to PROJECT.md **Keep local**. Do not delete it and do not replace it with a symlink. The doc site builds from git.
- Show me the deletion list (files that duplicate the template or the reviewer and are safe to remove). Do not delete yet.
- Fill PROJECT.md, seed or repair INDEX and architecture from the code (grep before citing; no secrets).
- Run install/install.sh, then --check.
- Run the project's pre-commit (or `git commit` of an empty-docs-safe change) and show the hook output.
- If a CI docs-impact job exists, show the updated job path.
- If the reviewer is on, tell me to run merge-reviewer's install/install-runtime.sh and bin/post-commit-review --dry-run.

Delete the listed duplicates only after --check, the pre-commit run, the CI job (if any), and the reviewer dry-run (if on) have succeeded. Tool symlinks stay uncommitted.
```
