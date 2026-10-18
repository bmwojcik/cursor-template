#!/usr/bin/env python3
"""Fail when an existing entry in docs/notes/ was edited, reordered, or removed.

Notes are append-only: the previous content of every notes file must stay a
prefix of the new content. Baseline per file: the HEAD blob when git tracks
it, otherwise a local snapshot under .git/agent-notes-baseline/ (repos that
hide docs/ from git). The snapshot is refreshed after every clean run.

  python3 tools/notes-append-only.py           worktree vs baseline (agents)
  python3 docs/scripts/notes-append-only.py --staged  index vs HEAD (pre-commit)

Humans only: NOTES_APPEND_ONLY_SKIP=1 accepts the current files as the new
baseline (e.g. to remove a leaked secret). Agents never set it.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

NOTES_REL = "docs/notes"
SNAPSHOT_NAME = "agent-notes-baseline"


def git(root: Path, *args: str) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(["git", *args], cwd=root, capture_output=True, check=False)


def repo_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise SystemExit("notes-append-only: not inside a git repository")
    return Path(result.stdout.strip())


def snapshot_dir(root: Path) -> Path:
    result = git(root, "rev-parse", "--git-path", SNAPSHOT_NAME)
    path = Path(result.stdout.decode().strip() or f".git/{SNAPSHOT_NAME}")
    return path if path.is_absolute() else root / path


def list_tree(root: Path, ref: str) -> set[str]:
    result = git(root, "ls-tree", "-r", "--name-only", ref, "--", NOTES_REL)
    if result.returncode != 0:
        return set()
    return {line for line in result.stdout.decode().splitlines() if line}


def list_index(root: Path) -> set[str]:
    result = git(root, "ls-files", "--cached", "--", NOTES_REL)
    return {line for line in result.stdout.decode().splitlines() if line}


def list_worktree(root: Path) -> set[str]:
    notes = root / NOTES_REL
    if not notes.is_dir():
        return set()
    return {p.relative_to(root).as_posix() for p in notes.rglob("*") if p.is_file()}


def list_snapshot(snapshots: Path) -> set[str]:
    if not snapshots.is_dir():
        return set()
    return {p.relative_to(snapshots).as_posix() for p in snapshots.rglob("*") if p.is_file()}


def blob(root: Path, spec: str) -> bytes | None:
    result = git(root, "show", spec)
    return result.stdout if result.returncode == 0 else None


def first_difference(old: bytes, new: bytes) -> str:
    old_lines = old.decode("utf-8", "replace").splitlines()
    new_lines = new.decode("utf-8", "replace").splitlines()
    for number, line in enumerate(old_lines, start=1):
        if number > len(new_lines):
            return f"line {number} removed: {line!r}"
        if new_lines[number - 1] != line:
            return f"line {number} changed: {line!r} -> {new_lines[number - 1]!r}"
    return "trailing content changed"


def is_append(old: bytes, new: bytes) -> bool:
    base = old.rstrip(b"\r\n")
    if not base:
        return True
    return new == base or new.startswith(base + b"\n") or new.startswith(base + b"\r\n")


def refresh_snapshot(root: Path, snapshots: Path, current: dict[str, bytes]) -> None:
    if snapshots.exists():
        shutil.rmtree(snapshots)
    for rel, content in current.items():
        target = snapshots / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--staged", action="store_true", help="read tracked notes from the index")
    args = parser.parse_args()

    root = repo_root()
    snapshots = snapshot_dir(root)
    in_head = list_tree(root, "HEAD")
    in_index = list_index(root) if args.staged else set()
    in_worktree = list_worktree(root)
    in_snapshot = list_snapshot(snapshots)

    current: dict[str, bytes] = {}
    for rel in in_worktree:
        current[rel] = (root / rel).read_bytes()
    if args.staged:
        for rel in in_index:
            staged = blob(root, f":{rel}")
            if staged is not None:
                current[rel] = staged
        for rel in in_head - in_index:
            current.pop(rel, None)

    if os.environ.get("NOTES_APPEND_ONLY_SKIP") == "1":
        refresh_snapshot(root, snapshots, current)
        print("notes-append-only: skipped (NOTES_APPEND_ONLY_SKIP=1); current notes are the new baseline")
        return 0

    violations: list[str] = []
    for rel in sorted(in_head | in_snapshot):
        if rel in in_head:
            old = blob(root, f"HEAD:{rel}")
            source = "HEAD"
        else:
            old = (snapshots / rel).read_bytes()
            source = "local snapshot"
        if old is None:
            continue
        new = current.get(rel)
        if new is None:
            violations.append(f"{rel}: removed (baseline: {source})")
            continue
        if not is_append(old, new):
            violations.append(f"{rel}: {first_difference(old, new)} (baseline: {source})")

    if violations:
        print("notes-append-only: docs/notes/ is append-only — existing entries must stay byte-for-byte.", file=sys.stderr)
        for violation in violations:
            print(f"- {violation}", file=sys.stderr)
        print("Restore the old text and add a new dated entry at the end (\"Supersedes …\") instead.", file=sys.stderr)
        if any("local snapshot" in violation for violation in violations):
            print(f"Last accepted text: {snapshots}", file=sys.stderr)
        print("Contract: AGENTS.md § Notes", file=sys.stderr)
        return 1

    refresh_snapshot(root, snapshots, current)
    print("notes-append-only: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
