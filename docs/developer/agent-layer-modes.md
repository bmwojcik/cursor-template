# Agent layer: committed or local

`.agent-tools/config.md` **Agent layer** chooses whether project docs are git history or a laptop-only layer. `PROJECT.md` is only the fallback when that file is missing. Tool symlinks are never committed in either mode. `install/link-project.sh` writes them into `.git/info/exclude` under `# >>> cursor-template`.

## committed

Tracked in the project repository:

- `PROJECT.md` and `.agent-tools/config.md` when the agent layer is committed
- `.agent-tools/vendored.lock` (sha256 of each copied team file)
- `OPERATING_MANUAL.md` (a copy, not a symlink)
- `docs/` (features, architecture, notes, templates if you materialise them)
- `.githooks/` stubs copied by the installer
- `docs/ci/docs-impact.py` and its config when **Docs impact** is `ci`
- `docs/ci/notes-append-only.py` when **Notes check** is `ci` (the default when Docs impact is `ci`)

Not tracked:

- symlinks to cursor-template (skills, shared rules, `docs/templates` when linked, `docs/scripts/notes-append-only.py`, and `docs/scripts/docs-impact.py` when Docs impact is `local`)

The cursor-template exclude block does not list vendored paths. `OPERATING_MANUAL.md` stays visible to git in a committed layer.

`git config core.hooksPath .githooks && chmod +x .githooks/* 2>/dev/null || true` is local git config plus a mode fix for checkouts where git does not restore the executable bit. Each clone runs the installer once. In a committed layer the index must store `.githooks/*` as `100755`.

## local

The same files exist on disk and stay out of `git status`, including `/.agent-tools/`. `install/agent-layer.sh install` writes `# >>> agent-layer` into `.git/info/exclude`.

`.cursor/rules/agent-tools.mdc` and `CLAUDE.local.md` are laptop files in every mode (each exists only for an Agent host that includes its tool, see `agent-hosts.md`). The cursor-template exclude block hides them even when the rest of the agent layer is committed.

Patterns hide untracked files only. A file that is already tracked still shows when you edit it.

When **Docs impact** is `ci`, the exclude list uses `/docs/*` and re-includes `docs/ci/` so CI can run a committed copy. Feature docs stay hidden. The laptop pre-commit then runs that committed script with `--include-hidden-since-head` and does not block: hidden feature docs cannot be staged, so the check is advisory and counts doc files edited since HEAD. CI still runs `docs/ci/docs-impact.py --staged` without that flag and can block the pipeline. Prefer `Docs impact: local` until the team commits the feature docs.

`sh install/agent-layer.sh check <project>` lists index paths that match the hide patterns. A match fails the check unless it is listed in **Agent layer tracked**. `install.sh --check` runs that same check when the layer is local.

## Intentionally tracked paths

**Agent layer tracked** in `.agent-tools/config.md` is a comma-separated list of repo-relative paths or shell globs that stay in git even though they match the hide list. `check` and `install.sh --check` print `tracked-allowed: <path>` for each match and still fail on every other match.

A value with no glob character is an exact path. A trailing slash is a directory prefix. `*`, `?`, and `[]` are shell globs.

```text
- **Agent layer tracked:** app/code/Acme/Widget/README.md
```

## Move local → committed

1. Set **Agent layer** to `committed` in `.agent-tools/config.md`.
2. If CI should run docs-impact, set **Docs impact** to `ci`. Add the job from `docs/scripts/gitlab-ci-docs-impact.example.yml`, `github-actions-docs-impact.example.yml`, or `bitbucket-pipelines-docs-impact.example.yml`. The script path in those jobs is `docs/ci/docs-impact.py`.
3. Run `install/install.sh <project>`. That removes the agent-layer exclude block (`agent-layer.sh uninstall`) and, when the CI script is missing, copies it. Link excludes stay.
4. `git status` now shows `PROJECT.md`, `AGENTS.md`, `CLAUDE.md`, `docs/`, and `.githooks/`. Review the diff. Do not add the symlinks (`git check-ignore -v` on one of them should name the cursor-template block).
5. Commit the project files. Links stay untracked on every laptop that has run the installer.
6. `install/install.sh <project> --check`.

Pack a local layer for a teammate with `install/agent-layer.sh pack <project> agent-layer.tar.gz`. They unpack at the repo root and run the installer.
