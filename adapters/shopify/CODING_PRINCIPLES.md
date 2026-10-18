# Coding principles — Shopify fragment

Append this to the project's `CODING_PRINCIPLES.md` when **Stack** is `shopify`. The generic file still applies.

## Theme and app

- Confirm whether this repo is a theme, an app, or an extension before copying a pattern. The code roots in `PROJECT.md` are the list.
- Escape dynamic output in Liquid and in the app's template layer.
- Do not commit merchant-edited content (theme settings data that the admin owns).
- Do not run a theme push, an app deploy, or a production config write unless the user asks.
- Metafield and metaobject keys are part of the contract. Grep them before citing a namespace or key.
- Webhook handlers must tolerate a replay and a missing shop record.

## Tests

- Use the command in `PROJECT.md` **Test paths**.
- Same change set as the production change when the project already has tests for that unit.
- Do not add a test runner the repository does not already use.
