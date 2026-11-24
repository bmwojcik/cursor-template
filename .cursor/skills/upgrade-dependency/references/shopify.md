# Shopify upgrade checklist

For `upgrade-dependency` step 2 and step 4. Upgrades here are: the theme base (for example a new Horizon or Dawn release merged into the theme), an installed app or its theme app extension, a sibling app's dependencies or Admin/Storefront API version, and npm tooling.

## Theme base update

- **Find our edits first.** Diff our theme against the upstream release we started from (`config/settings_schema.json` `theme_info.theme_version` names it). Files we changed are the consumers; upstream changes to the same files are merge conflicts in disguise.
- **Removed or renamed units.** For each snippet, block, and section removed or renamed upstream, grep our code for `render '<name>'`, `{% section '<name>' %}`, `{% content_for 'block', type: '<name>' %}`, `"type": "<name>"` in `templates/*.json`, `sections/*.json`, and block `presets`. A JSON template pointing at a missing type drops that section without an error.
- **Settings.** Removed or renamed ids in `settings_schema.json` and in section or block `{% schema %}` that our Liquid reads as `settings.<id>` or `section.settings.<id>` / `block.settings.<id>`. Merchant values in `config/settings_data.json` keep the old id and are ignored.
- **Locales.** Keys removed from `locales/*.json` that our Liquid calls with `| t`. A missing key renders the "translation missing" text.
- **JavaScript.** Custom elements, exported modules, and events (`document.addEventListener('<theme event>')`, `customElements.get(...)`) that our assets import or listen to; changed `data-` attributes and markup our scripts query.
- **CSS.** Classes and custom properties our CSS overrides.

## Apps

- **App blocks and embeds**: `shopify://apps/<app>/blocks/<handle>/...` in `templates/*.json`, `sections/*.json`, and `config/settings_data.json`. A handle the app removed makes the block disappear from the page with no error. After an app update, list these references and confirm each handle still exists in the app's theme extension.
- **Storefront contract** with an app or a sibling app: app proxy paths, metafield namespaces and keys, cart line properties, cart attributes. Changing either side is a change to both (`PROJECT.md` § Agent rules).
- **API versions**: sibling apps pin an Admin or Storefront API version. Read the version's changelog for removed fields before bumping, and grep the app for each removed field.

## Checks

- `shopify theme check` reports missing snippets, unknown filters, and some invalid JSON templates. It does not see app block handles or JS contracts.
- Preview the theme on an unpublished theme and open every template type that a consumer touches (product, collection, cart, account, each market). Never push to the published theme (`PROJECT.md` § Environment).
