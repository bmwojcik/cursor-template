# Implement this pack

Human landing a repository: paste [`NEW-PROJECT-PROMPT.md`](./NEW-PROJECT-PROMPT.md). This file is the agent's runbook. Do not invent a second docs system. Do not copy fictional names into live pages. Do not put secrets in any file you create.

The template checkout is the source of links. Do not fork skills, rules, or `tools/*.py` into the project except the CI copy of docs-impact described below.

## 0. Ask, then read

Ask the human, and wait, before writing files:

1. **Agent layer:** `committed` or `local`? This value goes in `.agent-tools/config.md`.
2. **Reviewer on this laptop:** yes or no? Yes links merge-reviewer. No runs `install/install.sh --without-reviewer`. It is not a git setting.
3. **Docs impact:** `ci`, `local`, or `off`? This value goes in `.agent-tools/config.md`.
4. **Agent host:** `cursor`, `claude`, or `both`? Default is the tool you are running in: Claude Code means `claude`, Cursor means `cursor`. The human may answer `both`. Pass it as `install/install.sh <project> --host <value>`; that writes `- **Agent host:**` in `.agent-tools/config.md`. See `docs/developer/agent-hosts.md`.

`PROJECT.md` is team guidance only: Overview, Stack prose, Code roots, Package naming, Environment (the only command list), Docs language, Quality bar, Agent rules, and optional Claude notes. No switches, versions, or tool paths.

Then detect **Stack**: `magento2` (`app/code` and `magento/product-*` in `composer.json`), `shopify` (theme or app layout), otherwise `generic`. Read `adapters/<stack>/` and `PROJECT.example.md`.

## 1. PROJECT.md

Copy `PROJECT.example.md` to `PROJECT.md` and `.agent-tools/config.example.md` to `.agent-tools/config.md`. Put the answers in `config.md`. Fill code roots, the Environment commands, git host, git project, and base branch. Leave unknown reproduce-ticket lines as `none`.

An existing repository that still has switches in `PROJECT.md` can run `install/install.sh <project> --migrate-config`. That moves the tool keys and `## Reproduce ticket` into `.agent-tools/config.md`, renames `## Review rules` to `## Quality bar` when Quality bar is missing, and writes `.git/agent-tools.local` only when Merge reviewer was `off`.

Append `## Agent rules` and `## Claude` from the real repo (overview, commands, environment). Use `###` inside those sections.

When the stack adapter has `CODING_PRINCIPLES.md` or `cursorrules.md`, append them only if the project does not already have that material. Never overwrite a working coding file.

## 2. Install

From the template checkout:

```bash
install/install.sh <project> --host <cursor|claude|both>
install/install.sh <project> --check
```

That links files in `install/links.txt`, sets `git config core.hooksPath .githooks && chmod +x .githooks/* 2>/dev/null || true`, copies hook stubs as mode 755, generates `AGENTS.md` and `CLAUDE.md`, and:

- **Agent host** `cursor` links only `.cursor/...` and writes `.cursor/rules/agent-tools.mdc`. `claude` links `.claude/skills`, `.claude/agents/implementer.md`, `.claude/rules/coding.md`, generates `.claude/rules/phpunit.md` (Magento 2), and writes `CLAUDE.local.md`. `both` (the default when the key is missing) does all of it. `AGENTS.md` and `CLAUDE.md` are written for every host; `CLAUDE.md` inlines `AGENTS.md` without its Cursor-only sections. With both hosts, `.cursorindexingignore` gets a managed block for the Claude files (never edited when git tracks it). Switching hosts removes the links and the generated laptop file of the host that was dropped.

- **Agent layer** `committed`: `[vendor:committed]` paths (today `OPERATING_MANUAL.md`) are real files. The sha256 is stored in `.agent-tools/vendored.lock`, which is committed with the layer. The exclude block does not list those paths. A copy that still matches the lock is updated when the template file changes. A hand-edited copy is left alone: `--check` prints `vendored-modified` and exits 1. `install.sh --sync-vendored` backs it up under `.git/cursor-template-backup/` and overwrites it.
- **Agent layer** `local`: those same paths stay symlinks and are excluded.
- **Docs impact** `ci` and missing `docs/ci/docs-impact.py`: copies the script and writes a config from the code roots.
- **Docs impact** `local`: links `tools/docs-impact.py` and writes `docs/scripts/docs-impact.config.json` when missing.
- **Notes check** `ci` (the default when Docs impact is `ci`): copies `docs/ci/notes-append-only.py` once. Later template edits do not replace that copy unless `--sync-vendored`. `--check` prints `vendored-stale` and still exits 0 when the copy matches the lock and the template has moved on.
- **Notes check** `local`: links `docs/scripts/notes-append-only.py`. **off**: the hook skips the notes check.
- **Agent layer** `local` writes the hide block in `.git/info/exclude`. **committed** removes that block.
- **Merge reviewer on this laptop:** the installer links it when the checkout exists and `.git/agent-tools.local` does not opt out. `--without-reviewer` writes that opt-out. A missing checkout does not fail install.
- **Keep local:** paths this repo commits itself (human doc pages the site builds from git). The linker skips each one: it does not create a symlink, it does not report a conflict when a real file is already there, and `--unlink` leaves the file. `--check` prints `kept-local` and still exits 0.

`--check` prints one line per feature and exits 1 on conflicts, a stale generated file, a missing CI script, or a reviewer switch with no checkout. A normal install does not fail solely because merge-reviewer is absent.

Edit generated `AGENTS.md` or `CLAUDE.md` only by editing `PROJECT.md` and re-running the installer. A file without the generator header, or a `.githooks` script without the cursor-template marker, is left alone. The installer prints one line naming `install/install.sh <project> --adopt`. `--adopt` copies those files to `.git/cursor-template-backup/<timestamp>/` and then overwrites them. Move any project-specific text into `PROJECT.md` first.

## 3. Seed docs from this code

`docs/features/INDEX.md` is the always-on entry. Copy the empty table shape from this pack's INDEX, then replace example rows with real capabilities.

1. One row per capability, not per file. Start with a handful of high-risk areas (payments, tax, shipping, checkout, ERP).
2. Columns: slug, canonical page, packages, keywords. Pointers only.
3. Architecture pages: current mechanism from this repo, 2–4 sentences, grep before you cite. No host IPs, no account IDs, no secrets.
4. `docs/features/<slug>.md` only when a capability spans packages. Copy `docs/templates/feature.md` (it is linked).
5. `docs/notes/_general.md` from `docs/templates` / this pack's notes page. Per-slug notes appear with their first entry. Append-only.

If a ticket disagrees with the code, document the code and say the ticket claim is unverified.

## 4. Docs impact on CI

When the switch is `ci`, commit `docs/ci/docs-impact.py`, `docs/ci/docs-impact.config.json`, and `docs/ci/notes-append-only.py`. Add a job from `docs/scripts/gitlab-ci-docs-impact.example.yml`, `github-actions-docs-impact.example.yml`, or `bitbucket-pipelines-docs-impact.example.yml`. That job runs both scripts. The notes script is `python3 docs/ci/notes-append-only.py --base <ref>`. Do not install hooks from `composer install` or `npm install`.

When the switch is `off`, do not add the job and do not tell the agent to run the script.

## 5. Reviewer

When the switch is `off`, stop. When it is `on`, tell the human to clone [merge-reviewer](https://github.com/bmwojcik/merge-reviewer), run its `install/install-runtime.sh`, then `bin/post-commit-review --dry-run` from the project root if that flag exists. Do not print `cursor.env`. Do not review the install in the same chat.

## 6. Stop

- Do not backfill every package README.
- Do not create `docs/changes/` unless asked.
- Do not copy this pack's example payment story into the live INDEX.
- Do not mention another shop, an agency, or a laptop path.
- Do not run destructive CLI or mutating SQL in order to document.

## Checks

- [ ] The switches and the agent host match the human's answers; `--check` prints `agent host: <value>`
- [ ] `install/install.sh <project> --check` exits 0, or the only failure is a reviewer checkout the human has not cloned yet. `team-ref-to-local` lines are fixed. `vendored-modified` is not left failing.
- [ ] INDEX rows cite paths that exist in this repo
- [ ] `docs-impact` config prefixes match `PROJECT.md` when the switch is not `off`
- [ ] Generated `AGENTS.md` contains `## Review policy` only when the reviewer is `on`
- [ ] Committed layer: `OPERATING_MANUAL.md` is a regular file and `git check-ignore -v OPERATING_MANUAL.md` is empty. Local layer: that path is a symlink and ignored.
