---
name: upgrade-dependency
description: Checks every place in this repository that extends or calls a third-party package, theme base, app, or platform API before a version change ships. Use when a diff changes composer.lock, package-lock.json, a theme_version, an app or API version, or adds or removes a patch to upstream code; when the user asks to upgrade, bump, or update a module, package, theme, app, or Magento/Shopify version; or when a bug appeared right after such an upgrade.
---

# Upgrade a third-party dependency

A version bump is a change to every consumer of that dependency in this repository, even when the diff touches only a lock file. Upstream can delete a class, a preference, a method, a snippet, a block, an event, or a setting without a major version, and the failure shows only at runtime, on the page that uses it.

Follow `AGENTS.md` § Third-party upgrades. Commands come from `PROJECT.md` § Environment. Stack checklists: `references/<stack>.md` (the Stack is in `.agent-tools/config.md`; `magento2`, `shopify`, otherwise `generic`).

## Workflow

1. **Versions.** Read the old and new version from the lock file on the base branch and in the working tree (`git show <base>:<lock>`). Collect every package whose version changes, including transitive ones. A jump over several releases means every release in between.
2. **Upstream diff.** Get both versions' source outside the project tree: the package's public repository (clone into a scratch or temp directory and `git diff <old> <new>`), or the old and new archives. Read the CHANGELOG and any UPGRADE notes for the whole range. List what was **removed, renamed, moved, or changed in signature**: classes, interfaces, DI preferences, public methods, events, config paths, tables and columns, templates, layout handles, snippets, blocks, settings, locale keys, API endpoints. An interface that stays but loses its only implementation counts as removed.
3. **Consumers, from the code.** Find every place in this repository that references the dependency: grep the package's namespaces, module name, template prefix, handles, or app handle across the code roots in `PROJECT.md`, theme overrides, patches, and config. Also find other installed third-party packages that require the upgraded one (they are consumers too, and their loose version constraints will not stop an incompatible bump). Then read the INDEX rows that mention the package. The INDEX is a second source, not the first: a consumer the INDEX does not list is still a consumer.
4. **Check each consumer** against the list from step 2, using the stack checklist. Run the stack's static scan when it has one, once on the base branch and once after the bump; only new findings are caused by the upgrade.
5. **Clean install.** Test against a dependency tree installed from the lock file, not a vendor or node_modules directory that already held the old version. Files left behind from the old version hide removals. Installing is a command to ask for, per `PROJECT.md`.
6. **Fix or flag.** A consumer that references something removed is blocking. Fix it in the same change set. Prefer a platform contract over the vendor's own API (for example the framework repository instead of the vendor's repository subclass). A fix in payment, checkout, pricing, tax, or cache code follows the project's stop-and-flag rule.
7. **Docs.** Update the INDEX row of the package so its modules or packages column names every consumer from step 3. Update the feature or architecture page when behaviour changed. Append a note (`AGENTS.md` § Notes) when upstream removed something without a changelog entry, or when a leftover file hid the break.
8. **Report** in the change description (and to the user):

| Consumer (path) | Uses from upstream | Status in new version | Action |
| --- | --- | --- | --- |
| `<path>` | `<type, method, file, or handle>` | unchanged / changed / removed | none / fixed in this diff / flagged |

Add the upstream range you diffed, the scan output before and after, and which runtime paths still need a manual test (for example "card payment redirect, PL and UK store").

## Do not

- Do not call an upgrade done because the install, a compile, or unit tests passed. Missing DI preferences, dead plugins, and removed templates pass all three.
- Do not edit vendor or upstream files. Patch only when the project already uses patches and the user agrees.
- Do not trust a local dependency directory that was upgraded in place.
- Do not run install, upgrade, compile, deploy, or cache commands that `PROJECT.md` lists as ask-first. Suggest them and wait.
