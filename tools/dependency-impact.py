#!/usr/bin/env python3
"""Advisory: which third-party versions changed, and which of our files are expected to need a look.

Compares lock files between git states, then looks each changed package up in the project's
dependency map (docs/architecture/dependency-map.md, written by the dependency-map skill).
It never fails a commit unless --strict is given. Stack-neutral: composer.lock, package-lock.json,
and a Shopify theme version (config/settings_schema.json) are understood.

Usage (from the repository root):
  python3 dependency-impact.py                 # HEAD vs working tree
  python3 dependency-impact.py --staged        # HEAD vs index (pre-commit)
  python3 dependency-impact.py --base origin/main
  python3 dependency-impact.py --check-map     # also report map entries whose version differs from the lock
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

MAP_DEFAULT = "docs/architecture/dependency-map.md"
LOCKS = ("composer.lock", "package-lock.json", "config/settings_schema.json")


def git(root: Path, *args: str) -> str | None:
    result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)
    return result.stdout if result.returncode == 0 else None


def versions(rel: str, text: str | None) -> dict[str, str]:
    if not text:
        return {}
    try:
        data = json.loads(text)
    except ValueError:
        return {}
    out: dict[str, str] = {}
    if rel == "composer.lock":
        for key in ("packages", "packages-dev"):
            for pkg in data.get(key) or []:
                out[pkg["name"]] = str(pkg.get("version", "?"))
    elif rel == "package-lock.json":
        for path, pkg in (data.get("packages") or {}).items():
            if path.startswith("node_modules/") and "/node_modules/" not in path[len("node_modules/"):]:
                out[path[len("node_modules/"):]] = str(pkg.get("version", "?"))
        for name, pkg in (data.get("dependencies") or {}).items():
            out.setdefault(name, str(pkg.get("version", "?")))
    elif rel == "config/settings_schema.json" and isinstance(data, list):
        for block in data:
            if isinstance(block, dict) and block.get("name") == "theme_info":
                out[f"theme:{block.get('theme_name', '?')}"] = str(block.get("theme_version", "?"))
    return out


def load_map(root: Path, rel: str) -> dict | None:
    path = root / rel
    if not path.is_file():
        return None
    match = re.search(r"<!-- dependency-map:data\n(.*?)\n-->", path.read_text(encoding="utf-8"), re.S)
    if not match:
        return None
    try:
        return json.loads(match.group(1))
    except ValueError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--base", help="git ref to compare against (merge-base with HEAD)")
    parser.add_argument("--staged", action="store_true", help="compare HEAD with the index")
    parser.add_argument("--map", default=MAP_DEFAULT, help=f"dependency map (default {MAP_DEFAULT})")
    parser.add_argument("--check-map", action="store_true", help="report map entries out of date with the lock")
    parser.add_argument("--strict", action="store_true", help="exit 1 when a high or medium risk package changed")
    args = parser.parse_args()

    top = git(Path.cwd(), "rev-parse", "--show-toplevel")
    if not top:
        print("dependency-impact: not a git repository; skipped", file=sys.stderr)
        return 0
    root = Path(top.strip())

    if args.base:
        base = (git(root, "merge-base", args.base, "HEAD") or args.base).strip()
        old_of = lambda rel: git(root, "show", f"{base}:{rel}")  # noqa: E731
        new_of = lambda rel: (root / rel).read_text(encoding="utf-8") if (root / rel).is_file() else None  # noqa: E731
    elif args.staged:
        old_of = lambda rel: git(root, "show", f"HEAD:{rel}")  # noqa: E731
        new_of = lambda rel: git(root, "show", f":{rel}")  # noqa: E731
    else:
        old_of = lambda rel: git(root, "show", f"HEAD:{rel}")  # noqa: E731
        new_of = lambda rel: (root / rel).read_text(encoding="utf-8") if (root / rel).is_file() else None  # noqa: E731

    dep_map = load_map(root, args.map)
    mapped = (dep_map or {}).get("packages", {})
    changes: list[tuple[str, str, str, str]] = []
    current: dict[str, str] = {}
    for rel in LOCKS:
        new = versions(rel, new_of(rel))
        current.update(new)
        old = versions(rel, old_of(rel))
        for name in sorted(set(old) | set(new)):
            if old.get(name) != new.get(name):
                changes.append((rel, name, old.get(name, "—"), new.get(name, "removed")))

    risky = 0
    if changes:
        print(f"dependency-impact: {len(changes)} third-party version change(s)")
        if dep_map is None:
            print(f"  no dependency map at {args.map}: consumers unknown. Build it with the dependency-map skill.")
        for rel, name, old, new in changes:
            entry = mapped.get(name)
            if not entry:
                if dep_map is not None:
                    print(f"  {name} {old} -> {new} ({rel}): not in the map, no known consumer in our code")
                else:
                    print(f"  {name} {old} -> {new} ({rel})")
                continue
            risk = entry.get("risk", "?")
            risky += risk in ("high", "medium")
            features = ", ".join(entry.get("features") or []) or "-"
            print(f"  {name} {old} -> {new} [risk {risk}] features: {features}")
            print("    expect changes or a re-check in:")
            seen = set()
            for ref in entry.get("refs", []):
                key = (ref["kind"], ref["file"])
                if key in seen:
                    continue
                seen.add(key)
                print(f"      - {ref['kind']}: {ref['file']} ({ref['symbol']})")
        print("  Next: run the upgrade-dependency skill for each package above; read upstream from the running container first.")
    if args.check_map and dep_map is not None:
        stale = [(n, e.get("version"), current.get(n)) for n, e in mapped.items() if current.get(n) and e.get("version") != current.get(n)]
        if stale:
            print(f"dependency-impact: the map is out of date for {len(stale)} package(s); regenerate it with the dependency-map skill")
            for name, was, now in stale:
                print(f"  {name}: map {was}, lock {now}")
    return 1 if (args.strict and risky) else 0


if __name__ == "__main__":
    sys.exit(main())
