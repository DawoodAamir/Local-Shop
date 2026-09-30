# Architecture

## App

`Sources/Core` contains Codable product, cart, address, quote, and order models. It is also a Swift package so pricing and persistence contracts can be tested without launching UIKit.

`ShopStore` owns published state on the main actor. It calls the `ShopService` protocol, persists successful local mutations atomically, and surfaces errors to the UI. `DemoService` reads the bundled catalog; `APIService` uses async URLSession and a Keychain guest credential. SwiftUI screens handle presentation and route user actions back through the store.

Local storage is in Application Support/LocalShop. Demo and connected states are separate files. A saved server origin prevents accidentally reusing a previous server's order cache with another endpoint. UI tests use a unique storage directory per launch.

## Checkout transaction

1. Validate delivery details and derive a quote from the displayed catalog.
2. Atomically save the request payload and UUID before contacting the server.
3. Authenticate the guest; validate the request and recalculate prices on the server.
4. In a SQLite transaction, insert the order or return the existing order for the same guest/key. A different payload with that key is rejected.
5. If Stripe test mode is configured, create a hosted session using the order ID as the Stripe idempotency key.
6. Save the returned order locally, clear the pending request, and empty the bag.

An interrupted network request keeps the original payload/key for retry. Bag edits are blocked while that request is unresolved. A definite validation or authentication rejection clears the pending request so the user can correct the issue. A failed local save keeps the earlier persisted state; retrying recovers the same server order.

## Payment status

Demo checkout returns `demo_confirmed`. Stripe checkout starts at `awaiting_payment`; authenticated refresh asks Stripe for its session. Matching amount, currency, order reference, test mode, and `paid` status are required for `test_paid`. A session expiry produces `expired`. The browser return endpoint only instructs the user to return to the app.

This intentionally has no automatic fulfilment. Production webhooks and jobs are documented as remaining deployment work rather than simulated as implemented integrations.

## Design

The storefront uses a restrained clay accent, a serif editorial heading, adaptive product cards, original vector illustrations, and native navigation, forms, and sheets. Prices and checkout actions stay explicit. System background/text colors support dark appearance; labels are not replaced by unexplained icons.
