---
name: dependency-map
description: Builds or refreshes the project's third-party dependency map (docs/architecture/dependency-map.md) - which of our modules, theme files, and patches extend or call which vendor package, with a risk level per package. Use when the map is missing or out of date, after adding or removing a plugin, preference, subclass, template override, or patch on vendor code, after a composer.lock change, or when the user asks for a dependency or risk map.
---

# Dependency map

One generated file per project: `docs/architecture/dependency-map.md`. It lists, per third-party package, every consumer in our code (plugins, preferences, subclasses, constructor injection, layout and template references, theme overrides, patches), the installed version, the constraint in the manifest, and a risk level. A machine-readable block at the end feeds `dependency-impact.py`, which turns a lock-file change into a list of files that are expected to need a look.

Follow `AGENTS.md` § Third-party upgrades. Commands come from `PROJECT.md` § Environment. Laptop-only paths (this skill's `scripts/`, `dependency-impact.py`) are listed in the local tool rules (`.cursor/rules/agent-tools.mdc` or `CLAUDE.local.md`).

## Why a scan of our code, not of the manifest

The manifest (`composer.json`, `package.json`) names only direct requirements. A package that arrives transitively (for example a theme module pulled in by the theme) can be upgraded without anyone deciding it, and its consumers are exactly the ones nobody checks. So the map starts from our code and resolves each reference to the package that owns it; the manifest only adds the constraint column.

## Where to read vendor code

- **Running container first.** Its dependency tree is what the shop runs. A local `vendor/` or `node_modules/` can be stale or upgraded in place.
- **Project files from the git checkout.** A container can hold an old copy of `patches/`, `docs/`, or config that is not mounted. Our code, patches, and docs are read from the working tree.
- **Fallback:** when the container is not running, read the local dependency tree and record that in the map header (`--source=local-vendor`). Say so to the user.

## Workflow

1. **Stack.** Read the Stack in `.agent-tools/config.md`.
2. **Generate.**
   - `magento2`: run `scripts/magento2-dependency-map.php` in two steps (commands in `PROJECT.md` § Environment). Step 1 runs in the container with `--emit-vendor-index` and writes the vendor index to `var/dependency-map.vendor.json`. Step 2 runs on the host from the repository root with `--vendor-index=var/dependency-map.vendor.json --source=container`, plus `--roots=<custom vendor dirs>` and `--lang=<docs language>`, and writes `docs/architecture/dependency-map.md`. Without a container, run step 2 alone with `--source=local-vendor`.
   - Other stacks: no generator yet. Write the same file by hand: the summary table and the `<!-- dependency-map:data … -->` block in the format described below, from a grep of our code (see the `upgrade-dependency` stack reference).
3. **Review the result.** The Health section lists theme overrides with no upstream original, patches for packages that are not installed, and wrappers with loose constraints. A template chosen at runtime (menu or email template set in the admin) can be a false positive; check before you call it dead. Do not hand-edit the generated file; fix the code or the generator.
4. **Check freshness.** Run `dependency-impact.py --check-map` (local tool rules). It reports map entries whose version differs from the lock file.
5. **Commit** the map with the change that caused it, like any current-state doc. Delete `var/dependency-map.vendor.json` or leave it in `var/` (not committed).
6. **Report** to the user: number of packages per risk level, new or removed high-risk couplings compared with the previous map (`git diff` of the file), and the Health findings.

## Data block format

The last lines of the map:

```text
<!-- dependency-map:data
{"stack": "<stack>", "lock": "<lock file>", "packages": {"<package>": {"version": "...", "constraint": "...", "risk": "high|medium|low", "consumers": ["..."], "features": ["<INDEX slug>"], "refs": [{"kind": "...", "consumer": "...", "symbol": "...", "file": "<path>"}]}}}
-->
```

`dependency-impact.py` reads only this block. A theme base on Shopify uses the package name `theme:<theme_name>`.

## Do not

- Do not run install, compile, or cache commands to build the map. The scripts read files only.
- Do not copy secrets or env values into the map.
