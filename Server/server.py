"""Local Shop reference API. Standard library only; bind locally by default."""
import hashlib
import json
import os
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen

CATALOG = json.loads(Path(__file__).with_name("catalog.json").read_text())
PRODUCTS = {p["id"]: p for p in CATALOG}

class APIError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message


def quote(items):
    if not isinstance(items, list) or not 1 <= len(items) <= 20:
        raise APIError(400, "Choose between 1 and 20 distinct products.")
    seen, lines = set(), []
    for item in items:
        if not isinstance(item, dict):
            raise APIError(400, "Invalid bag item.")
        pid, qty = item.get("productID"), item.get("quantity")
        if not isinstance(pid, str) or pid not in PRODUCTS or pid in seen:
            raise APIError(400, "Unknown or repeated product.")
        if type(qty) is not int or not 1 <= qty <= 20:
            raise APIError(400, "Quantity must be between 1 and 20.")
        seen.add(pid)
        p = PRODUCTS[pid]
        lines.append({"productID": pid, "name": p["name"], "quantity": qty, "unitPrice": p["price"]})
    subtotal = sum(x["quantity"] * x["unitPrice"] for x in lines)
    shipping = 0 if subtotal >= 7500 else 495
    return {"lines": lines, "subtotal": subtotal, "shipping": shipping, "total": subtotal + shipping, "currency": "usd"}


def address(value):
    if not isinstance(value, dict):
        raise APIError(400, "Enter a delivery address.")
    result = {}
    for key in ("name", "email", "street", "city", "region", "postalCode"):
        text = value.get(key)
        if not isinstance(text, str) or not 1 <= len(text.strip()) <= 160 or any(ord(c) < 32 for c in text):
            raise APIError(400, "Complete all delivery fields.")
        result[key] = text.strip()
    if "@" not in result["email"] or "." not in result["email"].split("@")[-1]:
        raise APIError(400, "Enter a valid email address.")
    if len(result["region"]) != 2 or not result["region"].isascii() or not result["region"].isalpha():
        raise APIError(400, "Use a two-letter US state code.")
    result["region"] = result["region"].upper()
    if not (len(result["postalCode"]) == 5 and result["postalCode"].isascii() and result["postalCode"].isdigit()):
        raise APIError(400, "Use a five-digit US ZIP code.")
    return result


class Shop:
    def __init__(self, path, stripe_key="", public_url="http://localhost:8080"):
        if stripe_key and not stripe_key.startswith("sk_test_"):
            raise ValueError("This reference server accepts Stripe test keys only.")
        self.path, self.stripe_key, self.public_url = path, stripe_key, public_url.rstrip("/")
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.db() as db:
            db.executescript("""
            CREATE TABLE IF NOT EXISTS sessions(token TEXT PRIMARY KEY, expires REAL NOT NULL);
            CREATE TABLE IF NOT EXISTS orders(id TEXT PRIMARY KEY, owner TEXT NOT NULL, request_key TEXT NOT NULL,
              fingerprint TEXT NOT NULL, payload TEXT NOT NULL, stripe_session TEXT, UNIQUE(owner, request_key));
            """)

    @contextmanager
    def db(self):
        db = sqlite3.connect(self.path, timeout=15)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def new_session(self):
        token = secrets.token_urlsafe(32)
        with self.db() as db:
            db.execute("INSERT INTO sessions VALUES (?, ?)", (self.digest(token), time.time() + 30 * 86400))
        return {"token": token}

    @staticmethod
    def digest(token):
        return hashlib.sha256(token.encode()).hexdigest()

    def authenticate(self, token):
        owner = self.digest(token)
        with self.db() as db:
            row = db.execute("SELECT expires FROM sessions WHERE token = ?", (owner,)).fetchone()
        if not row or row[0] <= time.time():
            raise APIError(401, "Your guest session expired. Start a new session in Settings.")
        return owner

    def stripe(self, method, path, fields=None, key=None):
        headers = {"Authorization": "Bearer " + self.stripe_key}
        if key:
            headers["Idempotency-Key"] = key
        body = urlencode(fields).encode() if fields is not None else None
        try:
            with urlopen(Request("https://api.stripe.com/v1/" + path, data=body, headers=headers, method=method), timeout=20) as response:
                return json.load(response)
        except (HTTPError, URLError, TimeoutError):
            raise APIError(502, "Payment service unavailable. Retry the same checkout safely.") from None

    def checkout(self, owner, body, request_key):
        try:
            uuid.UUID(request_key)
        except (ValueError, TypeError, AttributeError):
            raise APIError(400, "A valid checkout request key is required.")
        delivery = address(body.get("address"))
        totals = quote(body.get("items"))
        if type(body.get("expectedTotal")) is not int or body["expectedTotal"] != totals["total"]:
            raise APIError(409, "Prices changed. Refresh the bag and review the new total.")
        fingerprint = self.digest(json.dumps({"address": delivery, "quote": totals}, sort_keys=True))
        with self.db() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM orders WHERE owner = ? AND request_key = ?", (owner, request_key)).fetchone()
            if row:
                if row["fingerprint"] != fingerprint:
                    raise APIError(409, "This checkout key was already used for a different bag.")
                order = json.loads(row["payload"])
            else:
                order = {"id": str(uuid.uuid4()), "createdAt": time.time(), "status": "awaiting_payment" if self.stripe_key else "demo_confirmed", "paymentMode": "stripe_test" if self.stripe_key else "demo", "quote": totals, "address": delivery, "checkoutURL": None}
                db.execute("INSERT INTO orders VALUES (?, ?, ?, ?, ?, NULL)", (order["id"], owner, request_key, fingerprint, json.dumps(order)))
        if self.stripe_key and not order["checkoutURL"]:
            fields = {"mode": "payment", "payment_method_types[0]": "card", "client_reference_id": order["id"], "customer_email": delivery["email"], "success_url": self.public_url + "/payment-return", "cancel_url": self.public_url + "/payment-cancel", "metadata[order_id]": order["id"]}
            # Only server-owned amounts reach Stripe. No client-provided prices are trusted.
            for i, line in enumerate(totals["lines"] + [{"name": "Delivery", "unitPrice": totals["shipping"], "quantity": 1}]):
                fields.update({f"line_items[{i}][price_data][currency]": "usd", f"line_items[{i}][price_data][product_data][name]": line["name"], f"line_items[{i}][price_data][unit_amount]": line["unitPrice"], f"line_items[{i}][quantity]": line["quantity"]})
            session = self.stripe("POST", "checkout/sessions", fields, order["id"])
            if session.get("livemode") is not False:
                raise APIError(502, "Expected a test-mode payment session.")
            order["checkoutURL"] = session["url"]
            with self.db() as db:
                db.execute("UPDATE orders SET payload = ?, stripe_session = ? WHERE id = ?", (json.dumps(order), session["id"], order["id"]))
        return order

    def orders(self, owner):
        with self.db() as db:
            rows = db.execute("SELECT payload FROM orders WHERE owner = ? ORDER BY rowid DESC", (owner,)).fetchall()
        return [json.loads(row[0]) for row in rows]

    def refresh(self, owner, oid):
        with self.db() as db:
            row = db.execute("SELECT * FROM orders WHERE owner = ? AND id = ?", (owner, oid)).fetchone()
        if not row:
            raise APIError(404, "Order not found.")
        order = json.loads(row["payload"])
        if order["status"] == "awaiting_payment" and row["stripe_session"]:
            session = self.stripe("GET", "checkout/sessions/" + row["stripe_session"])
            if session.get("livemode") is not False or session.get("client_reference_id") != oid or session.get("amount_total") != order["quote"]["total"] or session.get("currency") != "usd":
                raise APIError(502, "Payment details could not be verified.")
            if session.get("payment_status") == "paid":
                order["status"] = "test_paid"
            elif session.get("status") == "expired":
                order["status"] = "expired"
            with self.db() as db:
                db.execute("UPDATE orders SET payload = ? WHERE id = ?", (json.dumps(order), oid))
        return order


def handler(shop):
    class Handler(BaseHTTPRequestHandler):
        # Do not log request bodies, credentials, or addresses.
        def log_message(self, *_):
            pass

        def reply(self, status, value):
            payload = json.dumps(value).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(payload)

        def handle_api(self):
            path = urlparse(self.path).path
            body = {}
            if self.command == "POST":
                size = int(self.headers.get("Content-Length", 0))
                if not 0 < size <= 16384:
                    raise APIError(413, "Request body must be 1–16384 bytes.")
                body = json.loads(self.rfile.read(size))
                if not isinstance(body, dict):
                    raise APIError(400, "Expected a JSON object.")
            if self.command == "GET" and path == "/health":
                return {"status": "ok", "paymentMode": "stripe_test" if shop.stripe_key else "demo"}
            if self.command == "GET" and path in ("/payment-return", "/payment-cancel"):
                return {"message": "Return to Local Shop and refresh your order to verify its payment status. No real payment is collected."}
            if self.command == "GET" and path == "/v1/catalog":
                return CATALOG
            if self.command == "POST" and path == "/v1/sessions":
                return shop.new_session()
            token = self.headers.get("Authorization", "").removeprefix("Bearer ")
            owner = shop.authenticate(token)
            if self.command == "POST" and path == "/v1/quote":
                return quote(body.get("items"))
            if self.command == "POST" and path == "/v1/checkout":
                return shop.checkout(owner, body, self.headers.get("Idempotency-Key"))
            if self.command == "GET" and path == "/v1/orders":
                return shop.orders(owner)
            if self.command == "POST" and path.startswith("/v1/orders/") and path.endswith("/refresh"):
                return shop.refresh(owner, path.split("/")[3])
            raise APIError(404, "Endpoint not found.")

        def dispatch(self):
            try:
                self.reply(200, self.handle_api())
            except APIError as error:
                self.reply(error.status, {"error": error.message})
            except (ValueError, UnicodeDecodeError):
                self.reply(400, {"error": "Invalid JSON request."})
            except Exception:
                self.reply(500, {"error": "The server could not complete this request."})

        do_GET = dispatch
        do_POST = dispatch
    return Handler


if __name__ == "__main__":
    shop = Shop(os.getenv("SHOP_DATABASE", str(Path(__file__).parent / "data/shop.sqlite")), os.getenv("STRIPE_SECRET_KEY", ""), os.getenv("SHOP_PUBLIC_URL", "http://localhost:8080"))
    server = ThreadingHTTPServer((os.getenv("SHOP_HOST", "127.0.0.1"), int(os.getenv("SHOP_PORT", "8080"))), handler(shop))
    print(f"Local Shop listening on {server.server_address}; payments: {'Stripe test' if shop.stripe_key else 'demo'}", flush=True)
    server.serve_forever()
