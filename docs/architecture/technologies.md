# Technologies

List the runtime **this repository** actually uses. Take names (and versions, if you state them) from lockfiles and committed config. Do not invent versions. Do not list a product because a previous shop used it.

## How to fill

1. Magento: `composer.lock` / `composer.json`, theme `package.json` / lockfile under the theme Tailwind (or equivalent) folder.
2. Shopify: app `package.json` / lockfile, extension TOMLs, Hydrogen/Remix lockfile.
3. Grep the lockfile for the package before you write the bullet. If it is not there, omit it.
4. A version is allowed only if you cite the lockfile (or `composer.json` constraint). Otherwise name the product without a version.
5. Delete the “Typical entries” list once the real list exists. Do not leave `REPLACE_ME` on a live shop.

## What to list (one bullet each, official docs link optional)

- **Commerce / application engine** — product + edition if the lockfile states it
- **Language runtime** — only if the repo pins it (`.php-version`, `engines` in package.json, Docker/base image **name**, not a host IP)
- **Storefront** — theme / CSS / JS runtime (e.g. utility CSS + island JS). Name the packages in the theme lockfile
- **Checkout stack** — only packages that exist here (checkout theme module, hosted checkout, checkout extensions)
- **Search** — engine the app is configured to use (from `env` *keys* / module config paths, not the DSN)
- **Cache / full-page cache** — application cache + HTTP cache in front of PHP/Node
- **Database** — engine family (do not paste hostnames)
- **Queue** — only if a queue package or connection exists in this repo
- **HTTP reverse proxy** — only if documented in this repo’s infra/docs or compose files
- **Observability packages in the lockfile** — error tracker, APM agent. No DSN, no account id

::: tip Typical entries (delete after filling)
- `REPLACE_ME` — commerce engine (lockfile)
- `REPLACE_ME` — storefront (theme lockfile)
- `REPLACE_ME` — checkout
- `REPLACE_ME` — search
- `REPLACE_ME` — cache / full-page cache
- `REPLACE_ME` — queue (omit if none)
- `REPLACE_ME` — observability package that exists in the lockfile
:::

Do not document account ids, DSNs, license keys, or “we also use X” from memory.
