# Example: split payment tiles

**Delete this file** when you add the first real feature page. It exists only to show tone and structure. Names below are fictional.

The shopper sees each wallet as its own checkout tile. Capture still goes through one merchant account.

## How it works

The vendor SDK renders one payment element. `Acme_PaymentSplit` lists wallet codes from config and shows each as a separate method when `payments/split_wallets/enabled` is on. On submit, `RewriteMethodOnSubmit` writes the vendor’s capture code onto the cart so the engine charges the single account.

## Packages and hooks

| Package | Role |
| --- | --- |
| `Acme_PaymentSplit` | tile list, method-code rewrite |
| `Vendor_Payments` | element, webhooks |
| theme / app payment templates | tile script list |

## Configuration

| Path | When empty |
| --- | --- |
| `payments/split_wallets/enabled` | `0` — one widget |
| `payments/split_wallets/codes` | empty list |

API keys, webhook signing secrets, and environment collection ids stay in environment config — not here.

## Contract

Tile codes are `vendor_wallet_a` and `vendor_wallet_b`. After submit the cart/order stores `vendor_payments`.

## Deliberately does not

Does not hard-code country lists. Availability comes from the vendor configuration API and market scope.

## Index

Row `example-payment-split` in [`docs/features/INDEX.md`](./INDEX.md). Map: [Integrations — example payment](../architecture/integrations.md#example-payment-gateway).
