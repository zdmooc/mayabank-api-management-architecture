"""Fast, deterministic security tests without Keycloak/Kong or a network."""
from __future__ import annotations

import concurrent.futures
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "payment-api"))
import app as service

PAYLOAD = {
    "debtorAccountId": "D1",
    "creditorIban": "FR7630006000011234567890189",
    "amount": {"value": "10.00", "currency": "EUR"},
}
KEY = "client-idem-key-00001"


class PaymentSecurityTests(unittest.TestCase):
    def setUp(self):
        service.app.config["TESTING"] = True
        with service._store_lock:
            service.payments.clear()
            service.idempotency.clear()
        self.key_patch = patch.object(
            service.jwks_client, "get_signing_key_from_jwt",
            return_value=SimpleNamespace(key="test-key"),
        )
        self.key_patch.start()
        self.decode_patch = patch.object(service.jwt, "decode", side_effect=self.fake_decode)
        self.decode_patch.start()
        self.addCleanup(self.key_patch.stop)
        self.addCleanup(self.decode_patch.stop)

    @staticmethod
    def fake_decode(token, *args, **kwargs):
        if token == "invalid":
            raise ValueError("invalid token")
        client, _, scopes = token.partition("|")
        return {"azp": client, "scope": scopes, "iss": service.EXPECTED_ISSUER}

    def post(self, principal="client-a", body=None, key=KEY):
        with service.app.test_client() as client:
            return client.post(
                "/payments", json=PAYLOAD if body is None else body,
                headers={
                    "Authorization": f"Bearer {principal}|payments.write payments.read",
                    "Idempotency-Key": key,
                },
            )

    def get(self, payment_id, principal="client-a"):
        with service.app.test_client() as client:
            return client.get(
                f"/payments/{payment_id}",
                headers={"Authorization": f"Bearer {principal}|payments.read"},
            )

    def test_owner_cannot_be_bypassed_with_read_scope(self):
        original = self.post()
        self.assertEqual(original.status_code, 201)
        pid = original.json["paymentId"]
        self.assertEqual(self.get(pid).status_code, 200)
        other = self.get(pid, "client-b")
        self.assertEqual(other.status_code, 404)

    def test_idempotency_isolated_by_client(self):
        first = self.post("client-a")
        second = self.post("client-b")
        self.assertEqual((first.status_code, second.status_code), (201, 201))
        self.assertNotEqual(first.json["paymentId"], second.json["paymentId"])
        self.assertEqual(self.get(first.json["paymentId"], "client-b").status_code, 404)
        self.assertEqual(self.post("client-a").headers["Idempotency-Replayed"], "true")

    def test_changed_payload_conflicts(self):
        self.assertEqual(self.post().status_code, 201)
        changed = {**PAYLOAD, "amount": {"value": "100.00", "currency": "EUR"}}
        result = self.post(body=changed)
        self.assertEqual(result.status_code, 409)
        self.assertEqual(result.json["code"], "idempotency_payload_mismatch")

    def test_invalid_payment_rejected_without_reserving_key(self):
        for invalid in [
            {**PAYLOAD, "extraneous": True},
            {**PAYLOAD, "creditorIban": "FR761234567890"},
            {**PAYLOAD, "amount": {"value": "-1", "currency": "EUR"}},
            {**PAYLOAD, "amount": {"value": "1.234", "currency": "EUR"}},
            {**PAYLOAD, "amount": {"value": "0", "currency": "EUR"}},
            {**PAYLOAD, "amount": {"value": "10.00", "currency": "EUR", "extra": 1}},
        ]:
            with self.subTest(payload=invalid):
                self.assertEqual(self.post(body=invalid).status_code, 422)
        self.assertEqual(self.post().status_code, 201)

    def test_client_identity_required(self):
        with service.app.test_client() as client:
            result = client.get(
                "/payments/anything", headers={"Authorization": "Bearer |payments.read"}
            )
        self.assertEqual(result.status_code, 401)

    def test_concurrent_same_key_creates_single_payment(self):
        def submit(_):
            result = self.post()
            return result.status_code, result.json["paymentId"]
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(submit, range(20)))
        self.assertEqual({code for code, _ in results}, {201})
        self.assertEqual(len({pid for _, pid in results}), 1)
        self.assertEqual(len(service.payments), 1)


if __name__ == "__main__":
    unittest.main()
