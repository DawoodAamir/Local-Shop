# Contributing

Preserve iOS 15 compatibility and integer-cent money calculations. Keep UI concerns out of `Sources/Core`. Run Swift package tests in Debug and Release, backend unit tests, and the Xcode UI suite with the local server running.

## Manual verification

- Check iPhone and iPad layouts, large Dynamic Type, VoiceOver reading order, and light/dark appearance.
- Add, increment, decrement, and remove products; verify the 20-item quantity limit and free-delivery threshold.
- Restart with a populated bag; verify it is restored.
- Disconnect the server during checkout, retry, and confirm only one order exists.
- Check invalid address fields, empty search, backend outage, and declined/cancelled/expired Stripe test payments.
- Verify guest isolation and confirm no other guest can fetch an order by its ID.
- Run on the oldest supported OS before claiming device-level compatibility.

Use concise Conventional Commits. Do not commit build artifacts, `.env` files, database contents, delivery addresses, access tokens, payment credentials, or signing identities. Keep demo data fictional.
