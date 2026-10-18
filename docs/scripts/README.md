# Scripts

Shared checkers live in the template checkout under `tools/`. Projects do not fork them except for **Docs impact** `ci`, which vendors a copy at `docs/ci/` so CI does not need the template.

| Path | Role |
| --- | --- |
| `tools/docs-impact.py` | Maps a diff onto `docs/features/INDEX.md`. Config: `docs/ci/docs-impact.config.json`, else `docs/scripts/docs-impact.config.json`. |
| `tools/docs-impact.config.example.json` | Seed for a new project. The installer fills code roots from `PROJECT.md` when the project file is missing. |
| `tools/notes-append-only.py` | Fails when an existing `docs/notes/` entry was edited or deleted. |
| `install/install.sh` | Links, hooks, generated agent docs. |
| `install/link-project.sh` | Symlinks only. |
| `install/agent-layer.sh` | Local-mode exclude block. |

```bash
python3 tools/docs-impact.py --staged
python3 tools/notes-append-only.py --staged
```

From a project after install, the same commands are `docs/ci/docs-impact.py` or `docs/scripts/docs-impact.py`, and `docs/scripts/notes-append-only.py`.

One-off skip on a laptop: `DOCS_IMPACT_SKIP=1`. Tokens `[skip docs-impact]` and `[skip docs]` apply once the commit exists (CI and `--base`).

Humans only: `NOTES_APPEND_ONLY_SKIP=1` accepts the current notes as the new baseline.

CI examples (path `docs/ci/docs-impact.py`):

- `gitlab-ci-docs-impact.example.yml`
- `github-actions-docs-impact.example.yml`
- `bitbucket-pipelines-docs-impact.example.yml`

The post-commit reviewer is [merge-reviewer](https://github.com/bmwojcik/merge-reviewer). It is not in this directory.
