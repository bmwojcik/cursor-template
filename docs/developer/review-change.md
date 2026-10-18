# Merge reviewer (optional)

The post-commit reviewer is not part of cursor-template. It lives in the optional repo [merge-reviewer](https://github.com/bmwojcik/merge-reviewer). A project works with the switch off. A missing checkout never fails a commit: the hook logs one line and exits 0.

## Enable

1. In `PROJECT.md` set **Merge reviewer** to `on` and **Merge reviewer version** to the minimum tag you accept. Fill **Review language**, **Review canvas labels**, **Pre-review command**, **Test paths**, **Base branch**, **Git host**, **Git project**, **Review model**, and `## Review rules` when you want them. The reviewer reads those keys. This template only documents them.
2. Clone merge-reviewer once per laptop. The discovery order is `MERGE_REVIEWER_HOME`, then `<project>/tools/merge-reviewer`, then the sibling of `CURSOR_TEMPLATE_HOME` (`$(dirname "$CURSOR_TEMPLATE_HOME")/merge-reviewer`). Both homes are keys in `~/.config/review-change/cursor.env`. That file also holds the API key. Never print or commit the key.
3. From the merge-reviewer checkout run `install/install-runtime.sh` (dashboard key, then reload the editor window).
4. From the cursor-template checkout run `install/install.sh <project>`. When the switch is `on` and the checkout exists, that runs merge-reviewer's `install/link-project.sh`.

The project hook `.githooks/post-commit` then runs `python3 "$MERGE_REVIEWER_HOME/bin/post-commit-review"` with the project root as the working directory.

## Check

`install/install.sh <project> --check` prints `merge-reviewer: on linked` or `merge-reviewer: on missing` and exits 1 when the switch is on and the checkout is missing.

Skip a run with `REVIEW_CHANGE=0` or `[skip review]` in the commit subject, or by committing on the base branch named in `PROJECT.md`. The reviewer itself documents canvas buttons and models. Claude Code does not spawn it.
