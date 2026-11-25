# Acme Shop — guidance

## Overview

Acme Shop is Magento Open Source. The patch level lives in `composer.json`.

## Stack

Magento Open Source with a Hyvä storefront when this repository has one. Confirm before assuming the theme.

## Code roots

```text
app/code/Acme/
app/design/frontend/Acme/default/
```

## Package naming

- **Module form:** `Vendor_Module` maps to `app/code/Vendor/Module/`
- **Theme or app roots:** `app/design/frontend/Acme/default/`

## Environment

```bash
../bin/cli
../bin/mysql -e "SELECT 1"
# Third-party upgrades (read-only; scripts ship in the skills' scripts/ directories, paths in the local tool rules)
# DI scan, in the container:
../bin/clinotty php -d memory_limit=2G -- /var/www/html --roots=Acme [--package=vendor/name] < <upgrade-dependency skill dir>/scripts/magento2-di-scan.php
# Dependency map: vendor index from the container, then the map from the checkout:
../bin/clinotty php -d memory_limit=2G -- /var/www/html --emit-vendor-index < <dependency-map skill dir>/scripts/magento2-dependency-map.php > var/dependency-map.vendor.json
php -d memory_limit=2G -- . --vendor-index=var/dependency-map.vendor.json --source=container --roots=Acme --lang=en < <dependency-map skill dir>/scripts/magento2-dependency-map.php > docs/architecture/dependency-map.md
```

Suggest cache and setup commands. Do not run them unless asked. Read-only SQL. Do not switch container tools.

## Docs language

- **Human docs:** English
- **Agent docs:** English

## Quality bar

- No new secrets in the diff.
- A behaviour change under `app/code/Acme` updates that module's unit test when `Test/Unit` already exists.
- Do not run `bin/magento`.
- A version change in `composer.lock` ships with the `upgrade-dependency` consumer table; a consumer that references a removed upstream type or method is blocking.

## Agent rules

### Modules

Custom code is `app/code/Acme`. Do not edit `vendor/magento`.
