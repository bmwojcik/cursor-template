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
```

Suggest cache and setup commands. Do not run them unless asked. Read-only SQL. Do not switch container tools.

## Docs language

- **Human docs:** English
- **Agent docs:** English

## Quality bar

- No new secrets in the diff.
- A behaviour change under `app/code/Acme` updates that module's unit test when `Test/Unit` already exists.
- Do not run `bin/magento`.

## Agent rules

### Modules

Custom code is `app/code/Acme`. Do not edit `vendor/magento`.
