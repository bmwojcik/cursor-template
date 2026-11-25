---
name: upgrade-dependency
description: Checks every place in this repository that extends or calls a third-party package, theme base, app, or platform API before a version change ships. Use when a diff changes composer.lock, composer.json, package-lock.json, a theme_version, an app or API version, or adds or removes a patch to upstream code; when dependency-impact reports a change; when the user asks to upgrade, bump, or update a module, package, theme, app, or Magento/Shopify version; or when a bug appeared right after such an upgrade.
---

# Upgrade a third-party dependency

A version bump is a change to every consumer of that dependency in this repository, even when the diff touches only a lock file. Upstream can delete a class, a preference, a method, a snippet, a block, an event, or a setting without a major version, and the failure shows only at runtime, on the page that uses it.

Follow `AGENTS.md` § Third-party upgrades. Commands come from `PROJECT.md` § Environment. Laptop-only paths (`dependency-impact.py`, this skill's `scripts/`) are in the local tool rules (`.cursor/rules/agent-tools.mdc` or `CLAUDE.local.md`). Stack checklists: `references/<stack>.md` (the Stack is in `.agent-tools/config.md`; `magento2`, `shopify`, otherwise `generic`).

## Where to read upstream code

1. **The running container** (or the environment named in `PROJECT.md`). Its dependency tree is what the shop runs.
2. **The upstream repository or archive** of the old and new version, cloned or unpacked into a scratch or temp directory, for the diff.
3. **The local `vendor/` or `node_modules/` last**, and say so in the report. It can be stale, or upgraded in place with files of the old version left behind.

Our own code, patches, and docs always come from the git checkout; a container can hold an old copy of files that are not mounted.

## Workflow

1. **Impact first.** Run `dependency-impact.py` (with `--base <base branch>` on a branch, `--staged` before a commit). It lists every changed package with the consumers from `docs/architecture/dependency-map.md`. When the map is missing or `--check-map` says it is stale, refresh it with the `dependency-map` skill before you go on.
2. **Versions.** Old and new version of every changed package, including transitive ones. A jump over several releases means every release in between.
3. **Upstream diff.** Diff the two versions (see "Where to read"). Read the CHANGELOG and UPGRADE notes for the whole range. List what was **removed, renamed, moved, or changed in signature**: classes, interfaces, DI preferences, public methods, events, config paths, tables and columns, templates, layout handles, snippets, blocks, settings, locale keys, API endpoints. An interface that stays but loses its only implementation counts as removed.
4. **Consumers.** Start from the map entry, then confirm in the code: grep the package's namespaces, module name, template prefix, handles, or app handle across the code roots, theme overrides, patches, and config. Also list other installed packages that require the upgraded one (the map's wrapper list). A consumer the map or the INDEX does not list is still a consumer.
5. **Check each consumer** against step 3 with the stack checklist. Run the stack's static scan, in the container first, once on the base branch and once after the bump; only new findings are caused by the upgrade.
6. **Clean install.** Test against a dependency tree installed from the lock file, not a directory upgraded in place. Installing is an ask-first command per `PROJECT.md`.
7. **Fix or flag.** A consumer that references something removed is blocking. Fix it in the same change set, preferring a platform contract over the vendor's own API. A fix in payment, checkout, pricing, tax, or cache code follows the project's stop-and-flag rule.
8. **Docs.** Regenerate the dependency map (`dependency-map` skill). Update the INDEX row of the package so it names every consumer. Update the feature or architecture page when behaviour changed. Append a note when upstream removed something without a changelog entry, or when a leftover file hid the break.
9. **Report** to the user and in the change description:

**Expected changes** — one line per consumer that the upgrade touches, for example: "`tpaycom/magento2basic` 2.1.7 → 2.9.1: `Indigo_PaymentReminder` `RedirectHandlerPlugin` injects `Tpay\Magento2\Api\Sales\OrderRepositoryInterface`, which has no implementation in 2.9.1 → change needed."

| Consumer (path) | Uses from upstream | Status in new version | Action |
| --- | --- | --- | --- |
| `<path>` | `<type, method, file, or handle>` | unchanged / changed / removed | none / fixed in this diff / flagged |

Add the upstream range you diffed, where you read the upstream code (container, upstream repository, or local vendor), the scan output before and after, and which runtime paths still need a manual test (for example "card payment redirect, PL and UK store").

## Do not

- Do not call an upgrade done because the install, a compile, or unit tests passed. Missing DI preferences, dead plugins, and removed templates pass all three.
- Do not edit vendor or upstream files. Patch only when the project already uses patches and the user agrees.
- Do not trust a local dependency directory that was upgraded in place.
- Do not run install, upgrade, compile, deploy, or cache commands that `PROJECT.md` lists as ask-first. Suggest them and wait.
