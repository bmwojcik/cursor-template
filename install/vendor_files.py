#!/usr/bin/env python3
"""Copy team files that must exist without the template checkout.

[vendor:committed] rows in links.txt are real files when Agent layer is
committed, and stay symlinks in local mode. docs/ci/notes-append-only.py is
copied when Notes check is ci and is not replaced unless --sync.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

KEY_RE_LINE = __import__("re").compile(r"^- \*\*(.+?):\*\*\s*(.*)$")
LOCK_NAME = ".agent-tools/vendored.lock"


def template_root() -> Path:
    return Path(__file__).resolve().parents[1]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def token(value: str) -> str:
    value = value.strip()
    return value.split()[0] if value else ""


def project_keys(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for line in text.splitlines():
        match = KEY_RE_LINE.match(line)
        if match:
            found[match.group(1).strip()] = match.group(2).strip().replace("`", "")
    return found


def load_keys(project: Path) -> dict[str, str]:
    config = project / ".agent-tools" / "config.md"
    if config.is_file():
        return project_keys(read_text(config))
    project_md = project / "PROJECT.md"
    if project_md.is_file():
        return project_keys(read_text(project_md))
    return {}


def notes_mode(keys: dict[str, str]) -> str:
    explicit = token(keys.get("Notes check", "")).lower()
    if explicit in {"ci", "local", "off"}:
        return explicit
    docs = token(keys.get("Docs impact", "off")).lower() or "off"
    if docs == "ci":
        return "ci"
    if docs == "local":
        return "local"
    return "off"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def parse_vendor_links(root: Path) -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    for raw in (root / "install" / "links.txt").read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if not line.startswith("[vendor:committed]"):
            continue
        parts = line.split("]", 1)[1].split()
        if len(parts) != 2:
            raise SystemExit(f"vendor: bad links.txt line: {raw}")
        rows.append((parts[0], parts[1]))
    return rows


def specs(root: Path, keys: dict[str, str]) -> list[tuple[str, str, str]]:
    layer = token(keys.get("Agent layer", "committed")).lower() or "committed"
    chosen: list[tuple[str, str, str]] = []
    if layer == "committed":
        for src, dest in parse_vendor_links(root):
            chosen.append((src, dest, "refresh"))
    if notes_mode(keys) == "ci":
        chosen.append(("tools/notes-append-only.py", "docs/ci/notes-append-only.py", "freeze"))
    return chosen


def read_lock(project: Path) -> dict[str, str]:
    path = project / LOCK_NAME
    found: dict[str, str] = {}
    if not path.is_file():
        return found
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        rel, _, digest = line.partition(" ")
        if rel and digest:
            found[rel] = digest.strip()
    return found


def write_lock(project: Path, locked: dict[str, str]) -> None:
    path = project / LOCK_NAME
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [f"{rel} {locked[rel]}" for rel in sorted(locked)]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def classify(dest: Path, source: Path, locked: str | None) -> str:
    if not dest.exists() and not dest.is_symlink():
        return "missing"
    if dest.is_symlink():
        return "link"
    current = sha256(dest)
    template = sha256(source)
    if current == template:
        return "current"
    if locked and current == locked:
        return "stale"
    return "modified"


def backup(project: Path, dest: Path) -> None:
    if not dest.exists() and not dest.is_symlink():
        return
    git = subprocess.run(
        ["git", "-C", str(project), "rev-parse", "--path-format=absolute", "--git-path", "cursor-template-backup"],
        capture_output=True,
        text=True,
        check=False,
    )
    root = Path(git.stdout.strip() or str(project / ".git" / "cursor-template-backup"))
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    target = root / stamp / dest.relative_to(project)
    target.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink():
        target.symlink_to(dest.readlink())
    elif dest.is_dir():
        shutil.copytree(dest, target)
    else:
        shutil.copy2(dest, target)
    print(f"install: backed up {dest.relative_to(project)} → {target}")


def install_bytes(source: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.is_symlink() or dest.is_file():
        dest.unlink()
    elif dest.is_dir():
        shutil.rmtree(dest)
    shutil.copy2(source, dest)
    if source.suffix == ".py":
        dest.chmod(dest.stat().st_mode | 0o111)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("project", type=Path)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--sync", action="store_true")
    args = parser.parse_args()
    project = args.project.resolve()
    root = template_root()
    keys = load_keys(project)
    locked = read_lock(project)
    failed = False
    changed = False
    for src_rel, dest_rel, policy in specs(root, keys):
        source = root / src_rel
        dest = project / dest_rel
        if not source.is_file():
            print(f"vendored-missing {dest_rel}", file=sys.stderr)
            failed = True
            continue
        state = classify(dest, source, locked.get(dest_rel))
        if args.check:
            if state == "stale":
                print(f"vendored-stale {dest_rel}")
            elif state == "modified":
                print(f"vendored-modified {dest_rel}")
                failed = True
            elif state == "missing":
                print(f"vendored-missing {dest_rel}", file=sys.stderr)
                failed = True
            elif state == "link":
                print(f"vendored-stale {dest_rel}")
            continue
        if state == "current":
            if locked.get(dest_rel) != sha256(source):
                locked[dest_rel] = sha256(source)
                changed = True
            continue
        if state == "modified" and not args.sync:
            print(f"vendored-modified {dest_rel}")
            failed = True
            continue
        if state == "stale" and policy == "freeze" and not args.sync:
            print(f"vendored-stale {dest_rel}")
            continue
        if state in {"modified", "stale", "link"}:
            backup(project, dest)
        install_bytes(source, dest)
        locked[dest_rel] = sha256(source)
        changed = True
        print(f"vendored: wrote {dest_rel}")
    if changed and not args.check:
        write_lock(project, locked)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
