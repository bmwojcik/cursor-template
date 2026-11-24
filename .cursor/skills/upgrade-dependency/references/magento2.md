# Magento 2 upgrade checklist

For `upgrade-dependency` step 2 and step 4. Custom code is the code roots in `PROJECT.md` (usually `app/code/<Vendor>/` and `app/design/`).

## Static scan

`scripts/magento2-di-scan.php` in this skill reads files only (Composer maps, `di.xml`, `events.xml`, constructors). It needs the PHP container because of `ext-simplexml`, and it is piped through stdin, so the skill directory does not have to be mounted. The container command is in `PROJECT.md` § Environment.

```bash
<container php> -d memory_limit=2G -- <magento-root-in-container> --roots=<Vendor1>,<Vendor2> [--package=<vendor/name>] < <skill-dir>/scripts/magento2-di-scan.php
```

Run it on the base branch and after the bump, then compare. `--package` keeps only references into that package's namespaces. Exit code 1 means a blocking finding.

| Finding | Meaning |
| --- | --- |
| `MISSING_CLASS` | Constructor, `di.xml`, or `events.xml` names a type that no longer exists |
| `INTERFACE_NO_PREFERENCE` | A required constructor argument is an interface that nothing implements in DI. Runtime: `Cannot instantiate interface` on first use |
| `PLUGIN_TARGET_MISSING` | The plugin's `<type name>` no longer exists |
| `PLUGIN_METHOD_NO_TARGET` | A `before`/`after`/`around` method whose target method is gone. The plugin silently stops running |
| `PLUGIN_METHOD_ON_IFACE` | Same, target is an interface. Check the implementation by hand |

The scan does not see `ObjectManager::get('...')` strings, layout block classes, templates, JavaScript, SQL, or changed method signatures. The checklist below covers those.

## What to diff upstream

`git diff <old> <new> --stat`, then read in this order:

- `etc/di.xml` and `etc/*/di.xml`: removed `<preference>`, renamed virtual types, removed or renamed plugins on classes we also plug into (plugin order changes).
- `etc/events.xml`, `etc/*/events.xml`, and `dispatch(` calls: an event we observe that is no longer dispatched means a silently dead observer.
- `Api/` and every class we inject, extend, or plug into: removed classes, removed public methods, changed signatures, changed return types.
- `etc/db_schema.xml` and data patches: tables, columns, and order statuses we read or filter on.
- `etc/config.xml` and `etc/adminhtml/system.xml`: config paths we read; new defaults that switch behaviour on (cron jobs, automatic cancellation, emails).
- `etc/crontab.xml`, `etc/email_templates.xml`, `etc/frontend/routes.xml`: new crons, emails, or routes that duplicate or interfere with ours.
- `view/*/layout/*.xml` and `view/*/templates/**`: removed handles, block names, and templates.
- The package's `composer.json`: new PHP or library constraints that move other packages (lock diff).

## Consumers to check

- **Constructor injection** of any upstream type, including `Factory` and `Proxy` of it.
- **`di.xml`**: `<plugin>` on upstream types, `<preference>` for upstream interfaces, `<type>` and `<virtualType>` arguments that name upstream classes.
- **Observers** on events the package dispatches.
- **Inheritance**: our classes that extend or implement upstream types; overridden protected methods.
- **Theme overrides** of the package's templates and layouts: `app/design/frontend/<Vendor>/<theme>/<Module_Name>/templates/**` and `layout/**`. Diff the upstream template we copied between old and new; an override hides upstream fixes and can call removed ViewModel or block methods.
- **Hyvä and checkout compatibility modules** (`hyva-themes/*`, `snowdog/*`, Magewire components) that wrap the package: their `composer.json` constraint is often loose, so check every upstream class and method they call.
- **Patches**: `patches/*.patch` and `composer.json` `extra.patches` against the package. A patch that no longer applies fails the install; a patch that still applies to moved code can do the wrong thing.
- **Config and data**: code, SQL, and grids that read the package's config paths, tables, columns, payment `additional_information` keys, or order statuses.
- **Our own docs** that name upstream classes: feature pages, notes, and READMEs.

## Runtime checks

Ask first (these are ask-first commands in most projects): reinstall the package from the lock so no old files remain, then `setup:upgrade` and `setup:di:compile` on a dev environment. `setup:di:compile` does **not** report a missing preference. Then exercise each storefront and admin path the consumers touch, on every store or market that uses the package (for payments: place an order with every method of that package and follow the redirect).
