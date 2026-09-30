import concurrent.futures
import json
import tempfile
import threading
import unittest
import uuid
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from http.server import ThreadingHTTPServer
from server import Shop, APIError, quote, handler

ADDRESS = dict(name="Alex Sample", email="alex@example.com", street="123 Example Street", city="Portland", region="OR", postalCode="97201")

def request_body():
    return {"items": [{"productID": "mug", "quantity": 2}], "address": ADDRESS.copy(), "expectedTotal": 5295}

class ShopTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.shop = Shop(str(Path(self.temp.name) / "shop.sqlite"))
        self.token = self.shop.new_session()["token"]
        self.owner = self.shop.authenticate(self.token)
    def tearDown(self):
        self.temp.cleanup()
    def test_authoritative_prices(self):
        payload = request_body(); payload["items"][0]["price"] = 1
        order = self.shop.checkout(self.owner, payload, str(uuid.uuid4()))
        self.assertEqual(order["quote"]["total"], 5295)
        payload["expectedTotal"] = 1
        with self.assertRaises(APIError) as caught:
            self.shop.checkout(self.owner, payload, str(uuid.uuid4()))
        self.assertEqual(caught.exception.status, 409)
    def test_invalid_quantities_and_duplicates(self):
        for qty in [0, -1, 21, True, 1.5, "2"]:
            with self.assertRaises(APIError): quote([{"productID": "mug", "quantity": qty}])
        with self.assertRaises(APIError): quote([{"productID": "mug", "quantity": 1}] * 2)
        with self.assertRaises(APIError): quote([{"productID": "unknown", "quantity": 1}])
    def test_retry_and_concurrent_requests_create_one_order(self):
        key = str(uuid.uuid4())
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
            results = list(pool.map(lambda _: self.shop.checkout(self.owner, request_body(), key), range(5)))
        self.assertEqual(len({o["id"] for o in results}), 1)
        self.assertEqual(len(self.shop.orders(self.owner)), 1)
        self.assertEqual(results[0]["status"], "demo_confirmed")
    def test_key_cannot_be_reused_for_different_order(self):
        key = str(uuid.uuid4()); self.shop.checkout(self.owner, request_body(), key)
        changed = request_body(); changed["address"]["name"] = "Another Sample"
        with self.assertRaises(APIError) as caught: self.shop.checkout(self.owner, changed, key)
        self.assertEqual(caught.exception.status, 409)
    def test_guest_isolation_and_expiration(self):
        order = self.shop.checkout(self.owner, request_body(), str(uuid.uuid4()))
        other = self.shop.authenticate(self.shop.new_session()["token"])
        self.assertEqual(self.shop.orders(other), [])
        with self.assertRaises(APIError): self.shop.refresh(other, order["id"])
        with self.shop.db() as db: db.execute("UPDATE sessions SET expires=0")
        with self.assertRaises(APIError): self.shop.authenticate(self.token)
    def test_orders_survive_server_restart(self):
        order = self.shop.checkout(self.owner, request_body(), str(uuid.uuid4()))
        reopened = Shop(self.shop.path)
        self.assertEqual(reopened.orders(reopened.authenticate(self.token)), [order])
    def test_live_keys_rejected(self):
        with self.assertRaises(ValueError): Shop(self.shop.path, "sk_live_not_a_real_key")
    def test_stripe_only_verified_paid_session_confirms_order(self):
        shop = Shop(self.shop.path, "sk_test_fixture")
        calls = []
        def fake(method, path, fields=None, key=None):
            calls.append((method, fields, key))
            return {"id": "cs_test_fixture", "url": "https://checkout.stripe.com/test", "livemode": False}
        shop.stripe = fake
        order = shop.checkout(self.owner, request_body(), str(uuid.uuid4()))
        self.assertEqual(order["status"], "awaiting_payment")
        self.assertEqual(calls[0][1]["line_items[0][price_data][unit_amount]"], 2400)
        self.assertEqual(calls[0][2], order["id"])
        paid = {"livemode": False, "client_reference_id": order["id"], "amount_total": 5295, "currency": "usd", "payment_status": "unpaid"}
        shop.stripe = lambda *_: paid
        self.assertEqual(shop.refresh(self.owner, order["id"])["status"], "awaiting_payment")
        paid["payment_status"] = "paid"; paid["amount_total"] = 1
        with self.assertRaises(APIError): shop.refresh(self.owner, order["id"])
        paid["amount_total"] = 5295
        self.assertEqual(shop.refresh(self.owner, order["id"])["status"], "test_paid")
    def test_invalid_address_rejected(self):
        payload = request_body(); payload["address"]["postalCode"] = "123"
        with self.assertRaises(APIError): self.shop.checkout(self.owner, payload, str(uuid.uuid4()))
    def test_shipping(self):
        self.assertEqual(quote([{"productID": "mug", "quantity": 3}])["shipping"], 495)
        self.assertEqual(quote([{"productID": "mug", "quantity": 4}])["shipping"], 0)
    def test_http_roundtrip_and_authentication(self):
        http = ThreadingHTTPServer(("127.0.0.1", 0), handler(self.shop))
        thread = threading.Thread(target=http.serve_forever, daemon=True); thread.start()
        base = f"http://127.0.0.1:{http.server_port}"
        try:
            with urlopen(base + "/health") as response: self.assertEqual(json.load(response)["paymentMode"], "demo")
            with self.assertRaises(HTTPError) as caught: urlopen(base + "/v1/orders")
            self.assertEqual(caught.exception.code, 401)
            headers = {"Authorization": "Bearer " + self.token, "Idempotency-Key": str(uuid.uuid4()), "Content-Type": "application/json"}
            with urlopen(Request(base + "/v1/checkout", data=json.dumps(request_body()).encode(), headers=headers)) as response:
                self.assertEqual(json.load(response)["quote"]["total"], 5295)
        finally:
            http.shutdown(); http.server_close(); thread.join()

if __name__ == "__main__": unittest.main()
