# cursor-template

Shared agent layer and documentation contract for any repository. One checkout per laptop. Each project links to it. A change here updates every linked project the next time an agent reads the symlink.

The optional post-commit reviewer is a second repo: [merge-reviewer](https://github.com/bmwojcik/merge-reviewer). This template does not contain it. A missing checkout logs one line and does not fail a commit.

## What you get

- A documentation contract: `docs/features/INDEX.md`, feature pages, append-only `docs/notes/`, architecture pages, ADRs.
- Agent instructions: `AGENTS.md`, `CLAUDE.md`, `OPERATING_MANUAL.md`, shared Cursor rules, skills (`update-feature-docs`, `reproduce-jira`).
- Stack adapters for Magento 2 and Shopify (PHPUnit skill and rule on Magento only).
- `docs-impact` (config-driven) and an append-only notes check.
- Hook stubs that call those tools and, when enabled, merge-reviewer.
- `install/install.sh` to link, generate, and wire a project.

Everyday coding uses Composer. Deep analysis uses Claude Opus and `OPERATING_MANUAL.md`. Cursor implementation workers use the newest Grok slug. The parent chat orchestrates.

## Two files

| File | Who reads it | What it holds |
| --- | --- | --- |
| `PROJECT.md` | every teammate | Overview, stack prose, code roots, environment and commands, docs language, quality bar, agent rules |
| `.agent-tools/config.md` | the laptop that linked the tools | Stack id, agent layer, docs impact, versions, git host, test commands, reproduce-ticket values |

`PROJECT.md` has no switches and no tool paths. Teammates who have not linked this checkout are not asked to read the tool config.

The reviewer is per laptop. It runs when this checkout's installer linked merge-reviewer for the project. `install/install.sh --without-reviewer` writes `- **Merge reviewer:** off` in `.git/agent-tools.local`. `--with-reviewer` removes that line.

Generated `AGENTS.md` and `CLAUDE.md` are team files. `.cursor/rules/agent-tools.mdc` and `CLAUDE.local.md` are rewritten on each install and are never committed.

Tool links are never committed. See `docs/developer/agent-layer-modes.md` to move a project from local to committed later.

## Quick start

Paste `NEW-PROJECT-PROMPT.md` into a new agent chat in the target repository. The agent asks three questions (agent layer, merge reviewer, docs impact), fills `PROJECT.md`, seeds docs from the code, and runs:

```bash
/path/to/cursor-template/install/install.sh /path/to/project
/path/to/cursor-template/install/install.sh /path/to/project --check
```

When the reviewer is on, the human runs merge-reviewer's `install/install-runtime.sh` and a dry run of `bin/post-commit-review`. This installer does not push and does not print API keys.

Machine config: `~/.config/review-change/cursor.env` with `CURSOR_TEMPLATE_HOME` and `MERGE_REVIEWER_HOME`. The installer writes `CURSOR_TEMPLATE_HOME` and removes a stale `REVIEW_CHANGE_HOME` line. Discovery for both tools: environment variable (also loaded from that file) → `<project>/tools/<name>` → for merge-reviewer, the sibling directory of `CURSOR_TEMPLATE_HOME`.

## Layout

```text
install/install.sh              wire one project
install/link-project.sh         absolute symlinks + exclude block
install/links.txt               template path → project path
install/generate-agent-docs.py  AGENTS.md and CLAUDE.md
install/agent-layer.sh          local-mode hide / list / pack / check
hooks/                          stubs copied into <project>/.githooks/
tools/docs-impact.py            config-driven docs check
tools/notes-append-only.py      append-only notes check
adapters/magento2|shopify|generic/
AGENTS.md  CLAUDE.md  OPERATING_MANUAL.md  CODING_PRINCIPLES.md
PROJECT.example.md  NEW-PROJECT-PROMPT.md  IMPLEMENT.md
```

## Updating

Edit this repo, commit, tag (`v0.2.0` is the split between team guidance and laptop tools). Linked projects pick up instruction changes immediately. A `Docs impact: ci` project keeps its own copy under `docs/ci/`; delete that copy and re-run the installer to refresh it. Bump **Cursor template version** in `.agent-tools/config.md` when a project must not run against an older checkout.

Do not put client names, keys, or laptop paths in this repository.
