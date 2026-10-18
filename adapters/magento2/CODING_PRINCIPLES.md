# Coding principles — Magento 2 fragment

Append this to the project's `CODING_PRINCIPLES.md` when **Stack** is `magento2`. The generic file still applies. Paths and the test command come from `PROJECT.md`, not from this fragment.

## PHP

- `declare(strict_types=1);` after the file header, before the namespace.
- Constructor injection only. No `ObjectManager` at runtime. A `static` factory inside a data patch or console command is the exception, because the object manager is not available there.
- Wire plugins, observers, preferences, and virtual types in `etc/di.xml` or `etc/<area>/di.xml`.
- Public API through `Api/` and `Api/Data/`. Implementations in `Model/`.
- `#[\Override]` on every override of a parent or interface method.
- Log with `Psr\Log\LoggerInterface`.
- PHPDoc on methods: `@param` and `@return` only. `@throws` only when that exception is the contract. No prose description that restates the method.

## Magento structure

- Schema: `etc/db_schema.xml` plus the whitelist. Data: `Setup/Patch/Data/*`. No `InstallData` or `UpgradeData` on new work.
- Resource table name: a class constant plus `$this->getTable(...)`.
- Model keys: constants on the API data interface.
- A plugin or observer that depends on another module declares `<sequence>` and `sortOrder`.
- Admin controllers need `etc/acl.xml`. Do not mix `frontend` and `adminhtml`.

## Defensive (Magento)

- `$scopeConfig->getValue()` may be `null` or `''`.
- Product attributes: `getData('code')` may be null, `'0'`, false, or absent. Do not use a magic getter for optional data.
- Repositories throw `NoSuchEntityException`.
- Guest group id is `0`. Never assume store id `1` or website id `1`.
- User-facing price: `getFinalPrice()`. Format with the price-currency and timezone interfaces.
- Product walkers tolerate `simple`, `configurable`, `bundle`, `grouped`, `virtual`, and `downloadable`.
- Customer-specific HTML behind a full-page cache: `cacheable="false"`, a private-content mechanism, or an equivalent. Do not mark it cacheable.

## Hot paths (Magento)

- No `load()`, `repository->get()`, or a new collection inside `foreach`.
- Never `addAttributeToSelect('*')` on a listing.
- Large sets: page size and `clear()`, or a query batch. Do not hydrate thousands of models.
- Do not plugin `getData`, `getFinalPrice`, or translation on a tight loop.
- Observers on `controller_action_predispatch` and `catalog_product_load_after` stay cheap.

## Storefront

When the theme is Hyvä (confirm in this repo before assuming it):

- No RequireJS, Knockout, or jQuery.
- HTML and CSS first. Alpine only when state cannot be done any other way.
- Tailwind classes must exist in this theme's config. Unknown classes are dropped at build time.
- Page CSS belongs to that page's source file, not the global sheet, when the theme splits CSS that way.
- Templates escape every dynamic value.

## Unit tests

- Path: `app/code/{Vendor}/{Module}/Test/Unit/`. Namespace matches the path.
- One test class per production class. Scenarios are `@dataProvider` rows or JSON under `Test/Unit/_files/`.
- PHPUnit 9 annotations when that is what this repo runs. Confirm before using a newer attribute style.
- `createMock` or a real DTO. No application `ObjectManager` in the test.
- Assert formatted money as strings when the code formats that way.
- Skill: `.cursor/skills/write-phpunit/SKILL.md`. Run the command in `PROJECT.md` **Test paths**, scoped to the module you changed.
- Do not open `dev/tests/integration` or `vendor/**/Test` in chat. Integration stays on CI.
