#!/usr/bin/env python3
"""Fail when a behaviour-bearing diff has no matching current-state docs.

Reads docs/features/INDEX.md and a config JSON file. Config search, from the
git repository that contains the current working directory:

  docs/ci/docs-impact.config.json
  docs/scripts/docs-impact.config.json
  docs-impact.config.json next to this script

Usage (from the project root):
  python3 docs/ci/docs-impact.py --staged
  python3 docs/scripts/docs-impact.py --base origin/main
  python3 tools/docs-impact.py --files-from -

`--staged` (the laptop pre-commit) does not read `[skip docs]` or `[skip docs-impact]`
from the previous commit. `DOCS_IMPACT_SKIP=1` is the one-off laptop skip.
Those subject tokens apply when the commit already exists (`--base`, CI).
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path, PurePosixPath

INDEX_REL = Path("docs/features/INDEX.md")
MODULE_NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9]*_[A-Za-z0-9]+$")
BACKTICK_RE = re.compile(r"`([^`]+)`")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
THEME_RE = re.compile(r"theme\s+`([^`]+)`", re.IGNORECASE)
COMPOSER_RE = re.compile(r"^[a-z0-9_.-]+/[a-z0-9_.-]+$")
SKIP_TOKENS = ("[skip docs-impact]", "[skip docs]")


@dataclass
class Config:
    custom_code_prefixes: list[str]
    theme_or_app_roots: list[str]
    module_folder_template: str
    core_module_prefixes: list[str]
    module_path_aliases: dict[str, list[str]]
    composer_path_aliases: dict[str, list[str]]
    skip_prefixes: list[str]
    skip_path_markers: list[str]
    skip_suffixes: list[str]


@dataclass
class IndexRow:
    slug: str
    doc_paths: list[str]
    feature_doc: str | None
    code_prefixes: list[str]
    filename_needles: list[str]
    modules: list[str]


@dataclass
class Report:
    missing: list[tuple[IndexRow, list[str]]] = field(default_factory=list)
    unmapped: list[tuple[str, list[str]]] = field(default_factory=list)
    skipped: str | None = None


def repo_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=Path.cwd(),
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        candidate = Path(result.stdout.strip())
        if (candidate / INDEX_REL).is_file():
            return candidate
    here = Path(__file__).resolve()
    for candidate in (Path.cwd(), *here.parents):
        if (candidate / INDEX_REL).is_file():
            return candidate
    raise SystemExit(f"Cannot find {INDEX_REL} from cwd or {here}")


def config_path(root: Path) -> Path:
    candidates = [
        root / "docs" / "ci" / "docs-impact.config.json",
        root / "docs" / "scripts" / "docs-impact.config.json",
        Path(__file__).resolve().parent / "docs-impact.config.json",
    ]
    for path in candidates:
        if path.is_file():
            return path
    names = ", ".join(str(path) for path in candidates)
    raise SystemExit(f"docs-impact: missing config. Looked for {names}")


def load_config(root: Path) -> Config:
    raw = json.loads(config_path(root).read_text(encoding="utf-8"))
    return Config(
        custom_code_prefixes=[posix(p) for p in raw.get("custom_code_prefixes", [])],
        theme_or_app_roots=[posix(p) for p in raw.get("theme_or_app_roots", [])],
        module_folder_template=str(raw.get("module_folder_template", "")),
        core_module_prefixes=list(raw.get("core_module_prefixes", [])),
        module_path_aliases={k: [posix(x) for x in v] for k, v in raw.get("module_path_aliases", {}).items()},
        composer_path_aliases={k: [posix(x) for x in v] for k, v in raw.get("composer_path_aliases", {}).items()},
        skip_prefixes=[posix(p) for p in raw.get("skip_prefixes", [])],
        skip_path_markers=list(raw.get("skip_path_markers", [])),
        skip_suffixes=list(raw.get("skip_suffixes", [])),
    )


def posix(path: str | Path) -> str:
    return str(PurePosixPath(str(path).replace("\\", "/")))


def under(path: str, prefix: str) -> bool:
    path = posix(path)
    prefix = posix(prefix).rstrip("/")
    return path == prefix or path.startswith(prefix + "/")


def is_skipped_code(path: str, cfg: Config) -> bool:
    path = posix(path)
    if any(path.startswith(p) for p in cfg.skip_prefixes):
        return True
    if any(m in f"/{path}/" or m in path for m in cfg.skip_path_markers):
        return True
    if path.endswith(tuple(cfg.skip_suffixes)):
        return True
    return False


def resolve_link(href: str, index_dir: Path, root: Path) -> str | None:
    href = href.strip()
    if href.startswith("http://") or href.startswith("https://"):
        return None
    href = href.split("#", 1)[0].split("?", 1)[0]
    if not href:
        return None
    resolved = (index_dir / href).resolve()
    try:
        return posix(resolved.relative_to(root))
    except ValueError:
        return None


def unique(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        item = posix(item)
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def is_core_module(module: str, cfg: Config) -> bool:
    return any(module.startswith(prefix) for prefix in cfg.core_module_prefixes)


def module_folder(module: str, cfg: Config) -> str | None:
    if not cfg.module_folder_template or not MODULE_NAME_RE.match(module):
        return None
    if is_core_module(module, cfg):
        return None
    vendor, name = module.split("_", 1)
    return posix(cfg.module_folder_template.format(vendor=vendor, name=name)).rstrip("/") + "/"


def module_code_prefixes(module: str, root: Path, cfg: Config) -> list[str]:
    if module in cfg.module_path_aliases:
        return list(cfg.module_path_aliases[module])
    prefixes: list[str] = []
    folder = module_folder(module, cfg)
    if folder:
        if (root / folder).is_dir() or any(
            under(folder, prefix) or folder.startswith(prefix.rstrip("/") + "/")
            for prefix in cfg.custom_code_prefixes
        ):
            prefixes.append(folder)
        elif any(
            prefix.rstrip("/").endswith(module.split("_", 1)[0]) or f"/{module.split('_', 1)[0]}/" in prefix
            for prefix in cfg.custom_code_prefixes
        ):
            prefixes.append(folder)
    for theme_root in cfg.theme_or_app_roots:
        prefixes.append(f"{theme_root.rstrip('/')}/{module}/")
    return prefixes


def module_readme(module: str, root: Path, cfg: Config) -> str | None:
    folder = module_folder(module, cfg)
    if not folder:
        return None
    readme = folder + "README.md"
    if not (root / readme).is_file():
        return None
    return readme


def parse_index(root: Path, cfg: Config) -> list[IndexRow]:
    text = (root / INDEX_REL).read_text(encoding="utf-8")
    rows: list[IndexRow] = []
    index_dir = (root / INDEX_REL).parent

    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 4:
            continue
        slug, canonical, modules_cell, keywords_cell = cells[0], cells[1], cells[2], cells[3]
        if slug in {"Slug", "---"} or slug.startswith("---") or slug.startswith("*"):
            continue
        if not re.match(r"^[a-z0-9][a-z0-9-]*$", slug):
            continue

        theme_modules = THEME_RE.findall(modules_cell)
        modules = BACKTICK_RE.findall(modules_cell)
        keywords = [k.strip() for k in keywords_cell.split(",") if k.strip()]
        keywords += BACKTICK_RE.findall(keywords_cell)

        doc_paths: list[str] = []
        for href in LINK_RE.findall(canonical):
            resolved = resolve_link(href, index_dir, root)
            if resolved:
                doc_paths.append(resolved)

        feature_rel = f"docs/features/{slug}.md"
        feature_doc = feature_rel if (root / feature_rel).is_file() else None
        if feature_doc and feature_doc not in doc_paths:
            doc_paths.insert(0, feature_doc)

        code_prefixes: list[str] = []
        for module in modules:
            code_prefixes.extend(module_code_prefixes(module, root, cfg))
            readme = module_readme(module, root, cfg)
            if readme:
                doc_paths.append(readme)

        for theme_module in theme_modules:
            for theme_root in cfg.theme_or_app_roots:
                code_prefixes.append(f"{theme_root.rstrip('/')}/{theme_module}/")

        filename_needles: list[str] = []
        for token in keywords + modules:
            token = token.strip("`").strip()
            if token in cfg.composer_path_aliases:
                code_prefixes.extend(cfg.composer_path_aliases[token])
            elif COMPOSER_RE.match(token):
                code_prefixes.append(f"vendor/{token.split('/')[0]}/")
            if "/" in token and not token.startswith("http") and not token.startswith("/V1/"):
                if not MODULE_NAME_RE.match(token):
                    code_prefixes.append(token if token.endswith("/") else token)
            if "/" in token:
                continue
            if "." in token or token.endswith("-script"):
                filename_needles.append(token)

        rows.append(
            IndexRow(
                slug=slug,
                doc_paths=unique(doc_paths),
                feature_doc=feature_doc,
                code_prefixes=unique(code_prefixes),
                filename_needles=unique(filename_needles),
                modules=modules,
            )
        )
    return rows


def row_matches_file(row: IndexRow, path: str) -> bool:
    path = posix(path)
    if any(under(path, prefix) for prefix in row.code_prefixes):
        return True
    name = path.rsplit("/", 1)[-1]
    for needle in row.filename_needles:
        if needle == name or needle in name:
            return True
    return False


def docs_updated_for_row(row: IndexRow, changed: list[str]) -> bool:
    index_changed = INDEX_REL.as_posix() in changed or posix(str(INDEX_REL)) in changed
    feature_changed = bool(row.feature_doc and row.feature_doc in changed)
    architecture_or_readme = False
    for doc in row.doc_paths:
        if doc in changed:
            if doc == row.feature_doc:
                feature_changed = True
            else:
                architecture_or_readme = True
    if row.feature_doc:
        return feature_changed
    return architecture_or_readme or index_changed


def is_custom_code(path: str, cfg: Config) -> bool:
    return any(under(path, prefix) for prefix in cfg.custom_code_prefixes + cfg.theme_or_app_roots)


def git_output(root: Path, args: list[str]) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def git_ok(root: Path, args: list[str]) -> bool:
    return (
        subprocess.run(
            ["git", *args],
            cwd=root,
            capture_output=True,
            text=True,
        ).returncode
        == 0
    )


def field_value(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        return ""
    if raw.startswith("`"):
        end = raw.find("`", 1)
        raw = raw[1:end].strip() if end > 1 else raw.strip("`")
    else:
        for separator in (" — ", " – "):
            if separator in raw:
                raw = raw.split(separator, 1)[0].strip()
                break
        raw = raw.strip("`").strip()
    lowered = raw.lower().rstrip(".")
    if lowered in {"", "none", "leave empty", "-"} or lowered.startswith(("leave empty", "empty")):
        return ""
    if raw.startswith(("—", "–")):
        return ""
    return raw


def project_fields(root: Path) -> tuple[dict[str, str], str]:
    path = root / ".agent-tools" / "config.md"
    if not path.is_file():
        path = root / "PROJECT.md"
    if not path.is_file():
        return {}, ""
    text = path.read_text(encoding="utf-8")
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = re.match(r"^\s*-\s+\*\*([^*]+)\*\*:?\s*(.*)$", line)
        if not match:
            continue
        key = re.sub(r"\s+", " ", match.group(1).strip().lower()).rstrip(":")
        fields[key] = field_value(match.group(2))
    return fields, text


def parse_suffixes(raw: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for part in raw.split(","):
        piece = part.strip()
        if "=" not in piece:
            continue
        suffix, ref = piece.split("=", 1)
        suffix, ref = suffix.strip(), ref.strip()
        if suffix and ref:
            pairs.append((suffix, ref))
    return pairs


def legacy_base(text: str) -> str:
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if not line.strip().lower().startswith("## default git base"):
            continue
        for follow in lines[index + 1 : index + 8]:
            stripped = follow.strip()
            if not stripped or stripped.startswith(("#", "```", "-")):
                continue
            return field_value(stripped)
        return ""
    return ""


def current_branch(root: Path) -> str:
    result = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return "HEAD"
    return result.stdout.strip() or "HEAD"


def detect_default_base(root: Path) -> str:
    override = os.environ.get("REVIEW_CHANGE_BASE", "").strip()
    if override and git_ok(root, ["rev-parse", "--verify", override]):
        return override
    fields, text = project_fields(root)
    base_branch = fields.get("base branch", "")
    if base_branch and git_ok(root, ["rev-parse", "--verify", base_branch]):
        return base_branch
    branch = current_branch(root)
    fallback = ""
    matched: tuple[int, str] | None = None
    for suffix, ref in parse_suffixes(fields.get("git base suffixes", "")):
        if suffix == "default":
            fallback = ref
            continue
        if branch.endswith(suffix) and (matched is None or len(suffix) > matched[0]):
            matched = (len(suffix), ref)
    if matched and git_ok(root, ["rev-parse", "--verify", matched[1]]):
        return matched[1]
    if fallback and git_ok(root, ["rev-parse", "--verify", fallback]):
        return fallback
    legacy = legacy_base(text)
    if legacy and git_ok(root, ["rev-parse", "--verify", legacy]):
        return legacy
    for candidate in ("origin/main", "main", "origin/master", "master"):
        if git_ok(root, ["rev-parse", "--verify", candidate]):
            return candidate
    return "HEAD"


def unique_paths(paths) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for path in paths:
        path = posix(path)
        if path not in seen:
            seen.add(path)
            out.append(path)
    return out


def is_doc_path(path: str) -> bool:
    path = posix(path)
    return path.startswith("docs/") or path.endswith("/README.md") or path == "README.md"


def hidden_docs_since_head(root: Path) -> list[str]:
    """Ignored doc files touched after the current HEAD commit.

    Local agent layers hide docs from the index, so a real edit never appears
    in --staged. mtime newer than HEAD is the signal that this commit's docs
    work already happened.
    """
    stamped = git_output(root, ["log", "-1", "--format=%ct"])
    if not stamped or not stamped[0].isdigit():
        return []
    since = int(stamped[0])
    fresh: list[str] = []
    for rel in git_output(root, ["ls-files", "-o", "-i", "--exclude-standard"]):
        if not is_doc_path(rel):
            continue
        file_path = root / rel
        if not file_path.is_file():
            continue
        try:
            mtime = file_path.stat().st_mtime
        except OSError:
            continue
        if int(mtime) > since:
            fresh.append(rel)
    return unique_paths(fresh)


def git_changed_files(
    root: Path,
    base: str | None,
    staged_only: bool,
    include_hidden_since_head: bool = False,
) -> list[str]:
    if staged_only:
        files = unique_paths(git_output(root, ["diff", "--name-only", "--cached"]))
        if include_hidden_since_head:
            files = unique_paths([*files, *hidden_docs_since_head(root)])
        return files
    if base is None:
        base = (
            os.environ.get("CI_MERGE_REQUEST_DIFF_BASE_SHA")
            or os.environ.get("CI_MERGE_REQUEST_TARGET_BRANCH_NAME")
            or detect_default_base(root)
        )
    if "/" not in str(base) and not re.fullmatch(r"[0-9a-f]{7,40}", str(base)):
        remote = f"origin/{base}"
        if git_ok(root, ["rev-parse", "--verify", remote]):
            base = remote
    spec = f"{base}...HEAD"
    files = git_output(root, ["diff", "--name-only", spec])
    files.extend(git_output(root, ["diff", "--name-only"]))
    files.extend(git_output(root, ["diff", "--name-only", "--cached"]))
    return unique_paths(files)


def should_skip(root: Path, staged: bool = False) -> str | None:
    if os.environ.get("DOCS_IMPACT_SKIP") in {"1", "true", "yes"}:
        return "DOCS_IMPACT_SKIP"
    if staged:
        return None
    subject = git_output(root, ["log", "-1", "--pretty=%s"])
    text = subject[0] if subject else ""
    for token in SKIP_TOKENS:
        if token in text:
            return token
    return None


def analyse(root: Path, changed: list[str], cfg: Config, staged: bool = False) -> Report:
    report = Report()
    skip = should_skip(root, staged)
    if skip:
        report.skipped = skip
        return report

    rows = parse_index(root, cfg)
    code_files = [p for p in changed if not is_skipped_code(p, cfg)]

    for path in code_files:
        if not is_custom_code(path, cfg):
            continue
        matches = [row for row in rows if row_matches_file(row, path)]
        if not matches:
            nearby = [row.slug for row in rows if any(m.lower() in path.lower() for m in row.modules)]
            report.unmapped.append((path, nearby))

    touched: dict[str, tuple[IndexRow, list[str]]] = {}
    for path in code_files:
        for row in rows:
            if row_matches_file(row, path):
                entry = touched.setdefault(row.slug, (row, []))
                entry[1].append(path)

    for row, paths in touched.values():
        if not docs_updated_for_row(row, changed):
            report.missing.append((row, unique(paths)))

    return report


def print_report(report: Report) -> int:
    if report.skipped:
        print(f"docs-impact skipped ({report.skipped})")
        return 0
    failed = False
    if report.missing:
        failed = True
        print("docs-impact: behaviour-bearing paths have no matching docs update")
        for row, paths in report.missing:
            owner = row.feature_doc or (row.doc_paths[0] if row.doc_paths else "(no canonical page)")
            print(f"  slug {row.slug} → update {owner}")
            for path in paths:
                print(f"    {path}")
    if report.unmapped:
        failed = True
        print("docs-impact: custom code is not mapped in INDEX.md")
        for path, nearby in report.unmapped:
            hint = f" (nearby slugs: {', '.join(nearby)})" if nearby else ""
            print(f"  {path}{hint}")
    if not failed:
        print("docs-impact: ok")
        return 0
    print("Add or edit the INDEX row and the canonical page. See AGENTS.md.")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description="Check that a diff updates matching current-state docs")
    parser.add_argument("--base", default=None, help="git base (default: origin/main or CI variable)")
    parser.add_argument("--staged", action="store_true", help="only staged files")
    parser.add_argument(
        "--include-hidden-since-head",
        action="store_true",
        help="also count ignored docs files modified after the HEAD commit",
    )
    parser.add_argument("--files-from", default=None, help="read paths from file, or - for stdin")
    args = parser.parse_args()

    root = repo_root()
    cfg = load_config(root)

    if args.files_from:
        source = sys.stdin if args.files_from == "-" else open(args.files_from, encoding="utf-8")
        with source:
            changed = unique_paths(line.strip() for line in source if line.strip())
        if args.include_hidden_since_head:
            changed = unique_paths([*changed, *hidden_docs_since_head(root)])
    else:
        changed = git_changed_files(root, args.base, args.staged, args.include_hidden_since_head)

    return print_report(analyse(root, changed, cfg, staged=args.staged))


if __name__ == "__main__":
    raise SystemExit(main())
