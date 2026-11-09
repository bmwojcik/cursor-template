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
- Cursor and Claude Code support: `--host cursor|claude|both` picks which tool's links and laptop files a laptop gets (`docs/developer/agent-hosts.md`). Claude Code gets `CLAUDE.md` routing, an `implementer` subagent, and rules.

In Cursor, everyday coding uses Composer 2.5 Fast, deep analysis uses Claude Opus and `OPERATING_MANUAL.md`, and implementation workers use the newest Grok slug. In Claude Code, implementation goes to the `implementer` subagent on Sonnet (see `CLAUDE.md`). The parent chat orchestrates in both.

## Two files

| File | Who reads it | What it holds |
| --- | --- | --- |
| `PROJECT.md` | every teammate | Overview, stack prose, code roots, environment and commands, docs language, quality bar, agent rules |
| `.agent-tools/config.md` | the laptop that linked the tools | Stack id, agent layer, docs impact, versions, git host, test commands, reproduce-ticket values |

`PROJECT.md` has no switches and no tool paths. Teammates who have not linked this checkout are not asked to read the tool config.

The reviewer is per laptop. It runs when this checkout's installer linked merge-reviewer for the project. `install/install.sh --without-reviewer` writes `- **Merge reviewer:** off` in `.git/agent-tools.local`. `--with-reviewer` removes that line.

Generated `AGENTS.md` and `CLAUDE.md` are team files. They do not point at laptop-only links. `.cursor/rules/agent-tools.mdc` (Cursor) and `CLAUDE.local.md` (Claude Code) hold skill and tool paths. They are rewritten on each install and are never committed. Which of them exists follows the **Agent host** (`cursor`, `claude`, or `both`, default `both`). Team files are written for every host.

In a committed layer, `OPERATING_MANUAL.md` and `docs/ci/notes-append-only.py` are real files, so a teammate without this checkout can still read the manual and CI can run the notes check. Other tool paths stay symlinks and are never committed. See `docs/developer/agent-layer-modes.md`.

## Quick start

Paste `NEW-PROJECT-PROMPT.md` into a new agent chat in the target repository. The agent asks four questions (agent layer, merge reviewer, docs impact, agent host), fills `PROJECT.md`, seeds docs from the code, and runs:

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
install/links.txt               template path → project path ([host:...] filters)
install/generate-agent-docs.py  AGENTS.md and CLAUDE.md
install/agent-layer.sh          local-mode hide / list / pack / check
hooks/                          stubs copied into <project>/.githooks/
tools/docs-impact.py            config-driven docs check
tools/notes-append-only.py      append-only notes check
adapters/magento2|shopify|generic/
claude/agents/                  Claude Code subagents, linked into .claude/agents
AGENTS.md  CLAUDE.md  OPERATING_MANUAL.md  CODING_PRINCIPLES.md
PROJECT.example.md  NEW-PROJECT-PROMPT.md  IMPLEMENT.md
```

## Updating

Edit this repo, commit, tag (`v0.2.0` is the split between team guidance and laptop tools). Linked projects pick up instruction changes immediately. A `Docs impact: ci` project keeps its own copy under `docs/ci/`; delete that copy and re-run the installer to refresh it. Bump **Cursor template version** in `.agent-tools/config.md` when a project must not run against an older checkout.

Do not put client names, keys, or laptop paths in this repository.
