# Agent host: Cursor, Claude Code, or both

The **Agent host** says which coding tool this laptop uses for the project. The installer links and generates only what that tool reads. The default is `both`, which is what the installer did before this key existed, plus the Claude Code files below.

| Value | Meaning |
| --- | --- |
| `cursor` | Cursor only |
| `claude` | Claude Code only |
| `both` | one laptop, both tools (default when the key is missing) |

## Where it is set

Effective host, first match wins:

1. `install/install.sh <project> --host cursor|claude|both`
2. `- **Agent host:** <value>` in `<git-dir>/agent-tools.local` (this laptop only; in a worktree, the worktree's own git dir)
3. `- **Agent host:** <value>` in `.agent-tools/config.md`
4. `both`

`--host` writes the value into `.agent-tools/config.md`. When `agent-tools.local` already has the key, it is updated too, so the override cannot hide the flag. A committed `.agent-tools/config.md` is shared by the team. A laptop that differs from the team value should keep its own line in `agent-tools.local` and not use `--host`.

`install/install.sh <project> --check` prints `agent host: <value>`.

## What each host gets

| | cursor | claude | both |
| --- | --- | --- | --- |
| `AGENTS.md`, `CLAUDE.md` (team files) | yes | yes | yes |
| `.cursor/skills/*`, `.cursor/rules/*` links | yes | no | yes |
| `.claude/skills/*` links | no | yes | yes |
| `.claude/agents/implementer.md` | no | yes | yes |
| `.claude/rules/coding.md` (link); `.claude/rules/phpunit.md` on Magento 2 (generated, test files only) | no | yes | yes |
| `.cursor/rules/agent-tools.mdc` (laptop file) | yes | removed | yes |
| `CLAUDE.local.md` (laptop file) | removed | yes | yes |
| `.cursorindexingignore` managed block (Claude files; untracked file only) | no | no | yes |
| `docs/developer/*`, `docs/templates`, scripts, hooks, `OPERATING_MANUAL.md` | yes | yes | yes |

Team files are written for every host because a teammate may use the other tool. They never name a laptop-only link.

`.claude/rules/coding.md` is a link to the Cursor `.mdc` file. Claude Code ignores the Cursor frontmatter keys and loads it every session. Claude Code asks once per project to approve rule files that live outside the project. Approve it, or the rule does not load. The Cursor `documentation.mdc` is not linked: it only points at `AGENTS.md`, whose contract is already inlined in `CLAUDE.md`.

`.claude/rules/phpunit.md` (Stack magento2) is a generated file, not a link, because Claude Code loads a symlinked rule from outside the project only when it has no `paths:` frontmatter. It carries `paths:` for `app/code/**/Test/**` and `dev/tests/**`, so it loads when Claude opens a test file. The Cursor rule is `alwaysApply`; the generated one drops its "Everyday work" section, and a one-line `## Tests` in `CLAUDE.md` carries that instead.

`CLAUDE.md` does not import `AGENTS.md`. The installer inlines the generated `AGENTS.md` into `CLAUDE.md` and drops every `## ` section whose heading contains `(Cursor only)` (today `## Delegation (Cursor only)`), so Claude Code does not pay for Cursor delegation text. The template `CLAUDE.md` holds the Claude-only header and sections and a `<!-- agents-contract -->` marker; `generate-agent-docs.py` composes the rest. Claude Code delegation (subagents, models) is in `CLAUDE.md`. Cursor delegation (Grok workers, Composer 2.5 Fast for search) is in `AGENTS.md` § Delegation.

## Switching

```bash
install/install.sh <project> --host claude    # both -> claude
install/install.sh <project> --host both      # claude -> both
```

When the host narrows, the installer removes the links it owns (symlinks that point into this checkout), deletes the generated laptop file of the other tool, and removes directories that became empty. Real files and project-authored rules are never touched. `.claude/settings.json` and `.claude/settings.local.json` are never touched.

The `# >>> cursor-template` block in `.git/info/exclude` lists the links of every host, so a git worktree that shares the exclude file with another checkout keeps working.

## One laptop, both tools

Leave the key out or set `both`. Cursor and Claude Code each find their own skills, rules, and generated laptop file. A change to a shared `.mdc` rule reaches both tools through the symlinks.

When merge-reviewer is on, it follows the same host. Cursor shows the canvas. Claude Code gets `var/review-change.html` and `var/review-change.md`, and a hook announces them. Update merge-reviewer too: an older checkout has no `--host` flag, and the installer then links its full set and prints a line saying so.

## Token budget

Each tool should load only its own instructions. Rows say what is read at session start unless noted.

| File | Cursor loads | Claude Code loads |
| --- | --- | --- |
| `AGENTS.md` | yes (reads it) | no, inlined in `CLAUDE.md` minus Cursor-only sections; told not to open it |
| `.cursorrules`, `.cursor/rules/*.mdc` (incl. `agent-tools.mdc`) | yes | no, told not to open `.cursor/**`; greps `.cursorrules` by heading only when `PROJECT.md` points there |
| `CLAUDE.md`, `CLAUDE.local.md` | not needed; the managed `.cursorindexingignore` block (host both) stops indexing | yes |
| `.claude/rules/coding.md` | no | yes |
| `.claude/rules/phpunit.md` | no | only after a test file is read or edited |
| `.claude/skills/*`, `.claude/agents/*` | may be read for compatibility; Claude-only descriptions start with "Claude Code only." | descriptions only; body on use |
| `var/review-change.*` | indexing-ignored (host both) | read only when asked |
| headless reviewer (`claude -p`) | n/a | project memory is not loaded: it runs in an empty temp directory with `--add-dir <repo>` |

`.cursorindexingignore` limits indexing only. The agent can still read a listed file. The installer never edits a git-tracked `.cursorindexingignore`; it prints one line with the entries to add. The block is removed when the host narrows or on `link-project.sh --unlink`; a file the installer created is deleted then and is hidden through `.git/info/exclude`.
