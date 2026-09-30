# Reference API

Python 3.10+; standard library only. Start from the repository root:

```sh
python3 Server/server.py
```

The default address is `127.0.0.1:8080`. SQLite state lives in ignored `Server/data/shop.sqlite`. The server does not log request bodies or access tokens.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `SHOP_DATABASE` | `Server/data/shop.sqlite` | Persistent database path. |
| `SHOP_HOST` | `127.0.0.1` | Bind address; use a proper HTTPS reverse proxy before any remote access. |
| `SHOP_PORT` | `8080` | Listener port. |
| `STRIPE_SECRET_KEY` | unset | Enables hosted Checkout when set to an `sk_test_` key. Live keys are rejected. |
| `SHOP_PUBLIC_URL` | `http://localhost:8080` | Absolute base URL for payment return/cancel pages. Use your HTTPS server origin for device testing. |

Environment files are ignored. The script reads environment variables; it does not automatically load `.env`. Never paste a key into source code, an Xcode setting, or a commit.

## API

All payloads are JSON. POST bodies are limited to 16 KiB. Amounts are integer USD cents.

| Method | Route | Authentication / behavior |
|---|---|---|
| GET | `/health` | Payment mode and health; public. |
| GET | `/v1/catalog` | Product catalog; public. |
| POST | `/v1/sessions` | `{}` → a random guest token. |
| POST | `/v1/quote` | Bearer token; `items` → authoritative totals. |
| POST | `/v1/checkout` | Bearer token + UUID `Idempotency-Key`; `items`, `address`, `expectedTotal` → order. |
| GET | `/v1/orders` | Bearer token; only that guest's orders. |
| POST | `/v1/orders/{id}/refresh` | Bearer token, `{}`; reconciles test payment directly with Stripe. |

Checkout item format: `{"productID":"mug","quantity":2}`. Address fields: `name`, `email`, `street`, `city`, `region` (two-letter state), and `postalCode` (five-digit ZIP). An order for two mugs totals 5,295 cents including delivery.

The token is a capability: possession grants access to that guest's orders. The server stores only its SHA-256 hash. Tokens expire after 30 days; starting a new guest session does not transfer old orders.

## Stripe test checkout

1. Supply your own Stripe **test** secret key through `STRIPE_SECRET_KEY` and start the server.
2. Connect the app, place an order using the sample address, then open the order and choose **Continue test payment**.
3. Use Stripe's documented test card data on its hosted checkout page.
4. Close the browser and refresh payment status. The server validates the session's order reference, currency, amount, test mode, and paid status before marking it `test_paid`.

A successful browser redirect is not proof of payment. Cancelled payment stays pending so it can be resumed; expired sessions are marked expired when refreshed. The reference server uses card payments only, with no Apple Pay entitlement or payment SDK in the app.

The Stripe API receives the supplied email, item names, and prices. Delivery details stay in the reference server's SQLite order. Do not enter real personal data for the portfolio demo.

Stripe creation requests reuse the order ID as the provider idempotency key. After an ambiguous provider failure, retry promptly: provider idempotency retention is finite, so long-abandoned requests need operator reconciliation before production use.

## Production boundary

`http.server` is for local development. Do not expose it directly to the internet or enable real payment keys. This reference does not implement tax, inventory, refunds, background reconciliation, webhook delivery, rate limiting, account recovery, or automatic data retention. There is no fulfilment side effect.

For a production integration, use a supported server framework, HTTPS, a secret manager, database migrations and backups, signed payment webhooks with replay protection, an idempotent fulfilment job, and explicit retention/deletion workflows.

References: [Stripe Checkout](https://docs.stripe.com/payments/checkout), [fulfilling orders](https://docs.stripe.com/checkout/fulfillment), [idempotent requests](https://docs.stripe.com/api/idempotent_requests), [test payments](https://docs.stripe.com/testing).
