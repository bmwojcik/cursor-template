# Agent layer: committed or local

`PROJECT.md` **Agent layer** chooses whether project docs are git history or a laptop-only layer. Tool symlinks are never committed in either mode. `install/link-project.sh` writes them into `.git/info/exclude` under `# >>> cursor-template`.

## committed

Tracked in the project repository:

- `PROJECT.md` and `.agent-tools/config.md` when the agent layer is committed
- `docs/` (features, architecture, notes, templates if you materialise them)
- `docs/` (features, architecture, notes, templates if you materialise them)
- `.githooks/` stubs copied by the installer
- `docs/ci/docs-impact.py` and its config when **Docs impact** is `ci`

Not tracked:

- symlinks to cursor-template (skills, shared rules, `OPERATING_MANUAL.md`, `docs/templates`, the notes check, and `docs/scripts/docs-impact.py` when Docs impact is `local`)

`git config core.hooksPath .githooks` is local git config. Each clone runs the installer once.

## local

The same files exist on disk and stay out of `git status`, including `/.agent-tools/`. `install/agent-layer.sh install` writes `# >>> agent-layer` into `.git/info/exclude`.

`.cursor/rules/agent-tools.mdc` and `CLAUDE.local.md` are laptop files in every mode. The cursor-template exclude block hides them even when the rest of the agent layer is committed.

Patterns hide untracked files only. A file that is already tracked still shows when you edit it.

When **Docs impact** is `ci`, the exclude list uses `/docs/*` and re-includes `docs/ci/` so CI can run a committed copy. Feature docs stay hidden. The laptop pre-commit then runs that committed script with `--include-hidden-since-head` and does not block: hidden feature docs cannot be staged, so the check is advisory and counts doc files edited since HEAD. CI still runs `docs/ci/docs-impact.py --staged` without that flag and can block the pipeline. Prefer `Docs impact: local` until the team commits the feature docs.

`sh install/agent-layer.sh check <project>` exits 1 when a hidden path is still visible in `git status`.

## Move local → committed

1. Set **Agent layer** to `committed` in `PROJECT.md`.
2. If CI should run docs-impact, set **Docs impact** to `ci`. Add the job from `docs/scripts/gitlab-ci-docs-impact.example.yml`, `github-actions-docs-impact.example.yml`, or `bitbucket-pipelines-docs-impact.example.yml`. The script path in those jobs is `docs/ci/docs-impact.py`.
3. Run `install/install.sh <project>`. That removes the agent-layer exclude block (`agent-layer.sh uninstall`) and, when the CI script is missing, copies it. Link excludes stay.
4. `git status` now shows `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, and `.githooks/`. Review the diff. Do not add the symlinks (`git check-ignore -v` on one of them should name the cursor-template block).
5. Commit the project files. Links stay untracked on every laptop that has run the installer.
6. `install/install.sh <project> --check`.

Pack a local layer for a teammate with `install/agent-layer.sh pack <project> agent-layer.tar.gz`. They unpack at the repo root and run the installer.
