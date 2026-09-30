# Privacy

Local Shop contains no analytics, ads, tracking SDKs, or remote product images.

Standalone mode stores the bag, pending checkout, and sample orders on the device. Connected mode sends the bag and entered delivery details to the server origin you configure; that server stores orders in SQLite. Guest access tokens are stored in device-only Keychain and hashed on the server. Stripe test mode sends the supplied email and order amounts to Stripe. Card entry occurs on Stripe's hosted page, never in this app or API.

Use the supplied fictional address for evaluation. Local app files use complete file protection. Deleting the app does not necessarily remove Keychain items or server records. Starting a new guest session removes the local token and access to its history; it does not delete server orders. The reference server has no automatic retention/deletion workflow. Its operator must manage database deletion and backups.

No real payments, deliveries, or customer accounts are offered by this portfolio project.
