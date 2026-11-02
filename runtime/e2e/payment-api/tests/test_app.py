"""Unit and contract tests for the Payment API fixture.

Tokens are signed with a throw-away RSA key generated per test session, and
every response body is validated against the component schemas of
apis/openapi/payment-api.yaml.
"""

from __future__ import annotations

import sys
import time
import uuid
from pathlib import Path

import jsonschema
import jwt
import pytest
import yaml
from cryptography.hazmat.primitives.asymmetric import rsa
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

API_DIR = Path(__file__).resolve().parents[1]
REPO_ROOT = API_DIR.parents[2]
sys.path.insert(0, str(API_DIR))

import app as payment_app  # noqa: E402

ISSUER = payment_app.EXPECTED_ISSUER
AUDIENCE = payment_app.AUDIENCE
VALID_IBAN = "FR1420041010050500013M02606"  # published sample IBAN, valid checksum
PAYLOAD = {
    "debtorAccountId": "D1",
    "creditorIban": VALID_IBAN,
    "amount": {"value": "10.00", "currency": "EUR"},
}

PRIVATE_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
OTHER_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)


class _SigningKey:
    key = PRIVATE_KEY.public_key()


class _FakeJwks:
    def get_signing_key_from_jwt(self, token):
        return _SigningKey()


# --- OpenAPI contract --------------------------------------------------------

CONTRACT = yaml.safe_load(
    (REPO_ROOT / "apis/openapi/payment-api.yaml").read_text(encoding="utf-8")
)
REGISTRY = Registry().with_resource(
    "urn:mayabank:payment-api",
    Resource.from_contents(CONTRACT, default_specification=DRAFT202012),
)


def assert_matches_schema(instance, schema_name: str):
    schema = {"$ref": f"urn:mayabank:payment-api#/components/schemas/{schema_name}"}
    jsonschema.Draft202012Validator(
        schema,
        registry=REGISTRY,
        format_checker=jsonschema.Draft202012Validator.FORMAT_CHECKER,
    ).validate(instance)


# --- helpers -----------------------------------------------------------------


def make_token(client="payment-client", scope="payments.read payments.write",
               aud=AUDIENCE, iss=ISSUER, key=PRIVATE_KEY, exp_delta=300, azp=True):
    claims = {"iss": iss, "aud": aud, "exp": int(time.time()) + exp_delta, "scope": scope}
    if azp:
        claims["azp"] = client
    return jwt.encode(claims, key, algorithm="RS256")


def auth(token, idem=None):
    headers = {"Authorization": f"Bearer {token}"}
    if idem:
        headers["Idempotency-Key"] = idem
    return headers


def new_key():
    return f"test-{uuid.uuid4()}"


def assert_problem(response, status, code):
    assert response.status_code == status, response.get_json()
    assert response.headers["Content-Type"].startswith("application/problem+json")
    body = response.get_json()
    assert_matches_schema(body, "Problem")
    assert body["code"] == code


@pytest.fixture(autouse=True)
def isolated_state(monkeypatch):
    monkeypatch.setattr(payment_app, "jwks_client", _FakeJwks())
    payment_app.payments.clear()
    payment_app.idempotency.clear()
    yield


@pytest.fixture
def client():
    payment_app.app.config["TESTING"] = True
    return payment_app.app.test_client()


# --- tests -------------------------------------------------------------------


def test_health(client):
    assert client.get("/health").get_json() == {"status": "UP"}


@pytest.mark.parametrize(
    "token_kwargs, code",
    [
        ({"aud": "other-api"}, "invalid_token"),
        ({"iss": "https://evil.example/realms/mayabank"}, "invalid_token"),
        ({"exp_delta": -60}, "invalid_token"),
        ({"key": OTHER_KEY}, "invalid_token"),
        ({"azp": False}, "missing_client_identity"),
    ],
)
def test_token_rejections(client, token_kwargs, code):
    response = client.post("/payments", json=PAYLOAD, headers=auth(make_token(**token_kwargs), new_key()))
    assert_problem(response, 401, code)


def test_missing_token(client):
    assert_problem(client.post("/payments", json=PAYLOAD), 401, "missing_token")


def test_insufficient_scope(client):
    token = make_token(scope="payments.read")
    assert_problem(client.post("/payments", json=PAYLOAD, headers=auth(token, new_key())), 403, "insufficient_scope")


def test_create_and_read_own_payment(client):
    token = make_token()
    created = client.post("/payments", json=PAYLOAD, headers=auth(token, new_key()))
    assert created.status_code == 201
    assert created.headers["Idempotency-Replayed"] == "false"
    body = created.get_json()
    assert_matches_schema(body, "Payment")

    read = client.get(f"/payments/{body['paymentId']}", headers=auth(token))
    assert read.status_code == 200
    assert read.get_json() == body
    assert_matches_schema(read.get_json(), "Payment")


def test_bola_other_client_gets_404(client):
    owner = make_token(client="payment-client")
    intruder = make_token(client="read-only-client", scope="payments.read")
    payment_id = client.post("/payments", json=PAYLOAD, headers=auth(owner, new_key())).get_json()["paymentId"]

    assert_problem(client.get(f"/payments/{payment_id}", headers=auth(intruder)), 404, "payment_not_found")
    assert_problem(client.get(f"/payments/{uuid.uuid4()}", headers=auth(intruder)), 404, "payment_not_found")


def test_idempotent_replay_same_payload(client):
    token, key = make_token(), new_key()
    first = client.post("/payments", json=PAYLOAD, headers=auth(token, key))
    second = client.post("/payments", json=PAYLOAD, headers=auth(token, key))
    assert second.status_code == 201
    assert second.headers["Idempotency-Replayed"] == "true"
    assert second.get_json() == first.get_json()
    assert len(payment_app.payments) == 1


def test_idempotency_key_reused_with_different_payload(client):
    token, key = make_token(), new_key()
    client.post("/payments", json=PAYLOAD, headers=auth(token, key))
    changed = {**PAYLOAD, "amount": {"value": "999.00", "currency": "EUR"}}
    assert_problem(client.post("/payments", json=changed, headers=auth(token, key)), 422, "idempotency_key_reused")
    assert len(payment_app.payments) == 1


def test_idempotency_key_is_scoped_per_client(client):
    key = new_key()
    a = client.post("/payments", json=PAYLOAD, headers=auth(make_token(client="client-a"), key)).get_json()
    b_response = client.post("/payments", json=PAYLOAD, headers=auth(make_token(client="client-b"), key))
    assert b_response.status_code == 201
    assert b_response.headers["Idempotency-Replayed"] == "false"
    assert b_response.get_json()["paymentId"] != a["paymentId"]


@pytest.mark.parametrize(
    "idem_key",
    ["short", "x" * 129, ""],
)
def test_invalid_idempotency_key(client, idem_key):
    headers = auth(make_token())
    if idem_key:
        headers["Idempotency-Key"] = idem_key
    assert_problem(client.post("/payments", json=PAYLOAD, headers=headers), 400, "invalid_idempotency_key")


@pytest.mark.parametrize(
    "mutation, status, code",
    [
        ({"padding": "x"}, 400, "unknown_fields"),
        ({"creditorIban": 123}, 400, "invalid_creditor_iban"),
        ({"creditorIban": "FR761234567890"}, 400, "invalid_creditor_iban"),
        ({"creditorIban": "FR7600000000000"}, 400, "invalid_creditor_iban"),
        ({"creditorIban": "ZZ7600000000000"}, 400, "invalid_creditor_iban"),
        ({"creditorIban": "FR1420041010050500013M02607"}, 422, "invalid_creditor_iban"),
        ({"creditorIban": "fr1420041010050500013m02606"}, 400, "invalid_creditor_iban"),
        ({"amount": {"value": "10.001", "currency": "EUR"}}, 400, "invalid_amount"),
        ({"amount": {"value": "0", "currency": "EUR"}}, 422, "invalid_amount"),
        ({"amount": {"value": "10.00", "currency": "eur"}}, 400, "invalid_currency"),
        ({"amount": {"value": "10.00", "currency": "ZZZ"}}, 422, "invalid_currency"),
        ({"amount": {"value": "999999999999999999999999999999999999.99", "currency": "EUR"}}, 422, "invalid_amount"),
        ({"amount": {"value": "10.00", "currency": "EUR", "fx": "1"}}, 400, "invalid_amount"),
        ({"debtorAccountId": "D 1"}, 400, "invalid_debtor_account"),
    ],
)
def test_request_validation(client, mutation, status, code):
    body = {**PAYLOAD, **mutation}
    assert_problem(client.post("/payments", json=body, headers=auth(make_token(), new_key())), status, code)
    assert payment_app.payments == {}


def test_missing_field(client):
    body = {k: v for k, v in PAYLOAD.items() if k != "creditorIban"}
    assert_problem(client.post("/payments", json=body, headers=auth(make_token(), new_key())), 400, "missing_fields")


def test_non_object_body(client):
    response = client.post("/payments", data="[]", content_type="application/json",
                           headers=auth(make_token(), new_key()))
    assert_problem(response, 400, "invalid_body")
