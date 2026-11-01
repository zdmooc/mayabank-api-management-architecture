from __future__ import annotations

import hashlib
import json
import os
import re
import threading
import uuid
from decimal import Decimal, InvalidOperation
from functools import wraps

import jwt
from flask import Flask, jsonify, request
from jwt import PyJWKClient

app = Flask(__name__)
EXPECTED_ISSUER = os.environ.get("OIDC_EXPECTED_ISSUER", "http://localhost:8080/realms/mayabank")
JWKS_URL = os.environ.get(
    "OIDC_JWKS_URL", "http://keycloak:8080/realms/mayabank/protocol/openid-connect/certs"
)
AUDIENCE = os.environ.get("OIDC_AUDIENCE", "payment-api")

jwks_client = PyJWKClient(JWKS_URL)
# IN-MEMORY LAB FIXTURE ONLY: a single process, no durability or multi-replica guarantees.
payments: dict[str, dict] = {}
idempotency: dict[tuple[str, str, str], tuple[str, str]] = {}
_store_lock = threading.RLock()
IDEMPOTENCY_KEY = re.compile(r"^[A-Za-z0-9._:-]{16,128}$")
MONEY_VALUE = re.compile(r"^[0-9]+(?:\.[0-9]{1,2})?$")
CURRENCY = re.compile(r"^[A-Z]{3}$")
IBAN = re.compile(r"^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$")


def problem(status: int, title: str, code: str):
    return (
        jsonify({
            "type": "about:blank", "title": title, "status": status, "code": code,
            "correlationId": request.headers.get("X-Correlation-ID", ""),
        }),
        status,
        {"Content-Type": "application/problem+json"},
    )


def require_scope(scope: str):
    def decorator(func):
        @wraps(func)
        def wrapped(*args, **kwargs):
            auth = request.headers.get("Authorization", "")
            if not auth.startswith("Bearer "):
                return problem(401, "Unauthorized", "missing_token")
            try:
                token = auth.removeprefix("Bearer ").strip()
                key = jwks_client.get_signing_key_from_jwt(token)
                claims = jwt.decode(
                    token, key.key, algorithms=["RS256"], audience=AUDIENCE,
                    issuer=EXPECTED_ISSUER, options={"require": ["exp", "iss"]},
                )
            except Exception:
                return problem(401, "Unauthorized", "invalid_token")
            # The lab explicitly models OAuth2 client_credentials: azp is the
            # authenticated client ID, not a client-controlled HTTP header.
            client_id = claims.get("azp")
            if not isinstance(client_id, str) or not client_id or len(client_id) > 200:
                return problem(401, "Unauthorized", "missing_client_identity")
            if scope not in set(str(claims.get("scope", "")).split()):
                return problem(403, "Forbidden", "insufficient_scope")
            request.client_id = client_id
            request.jwt_claims = claims
            return func(*args, **kwargs)
        return wrapped
    return decorator


def valid_iban(iban: str) -> bool:
    if not IBAN.fullmatch(iban):
        return False
    if iban.startswith("FR") and len(iban) != 27:
        return False
    rearranged = iban[4:] + iban[:4]
    remainder = 0
    for char in rearranged:
        digits = str(ord(char) - 55) if char.isalpha() else char
        for digit in digits:
            remainder = (remainder * 10 + int(digit)) % 97
    return remainder == 1


def valid_payment_request(body: object) -> bool:
    if not isinstance(body, dict) or set(body) != {"debtorAccountId", "creditorIban", "amount"}:
        return False
    debtor, creditor, amount = body["debtorAccountId"], body["creditorIban"], body["amount"]
    if not isinstance(debtor, str) or not (1 <= len(debtor) <= 128):
        return False
    if not isinstance(creditor, str) or not valid_iban(creditor):
        return False
    if not isinstance(amount, dict) or set(amount) != {"value", "currency"}:
        return False
    value, currency = amount["value"], amount["currency"]
    if not isinstance(value, str) or not MONEY_VALUE.fullmatch(value):
        return False
    if not isinstance(currency, str) or not CURRENCY.fullmatch(currency):
        return False
    try:
        return Decimal(value).is_finite() and Decimal(value) > 0
    except InvalidOperation:
        return False


@app.get("/health")
def health():
    return jsonify({"status": "UP"})


@app.post("/payments")
@require_scope("payments.write")
def create_payment():
    idem_key = request.headers.get("Idempotency-Key", "")
    if not IDEMPOTENCY_KEY.fullmatch(idem_key):
        return problem(400, "Invalid request", "invalid_idempotency_key")
    body = request.get_json(silent=True)
    if not valid_payment_request(body):
        return problem(422, "Invalid payment request", "invalid_payment_payload")
    fingerprint = hashlib.sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    ).hexdigest()
    # Operation and authenticated OAuth client are part of the idempotency namespace.
    key = (request.client_id, "POST /payments", idem_key)
    with _store_lock:
        existing = idempotency.get(key)
        if existing:
            old_hash, payment_id = existing
            if old_hash != fingerprint:
                return problem(409, "Idempotency conflict", "idempotency_payload_mismatch")
            response = jsonify(payments[payment_id]["response"])
            response.status_code = 201
            response.headers["Idempotency-Replayed"] = "true"
            return response

        payment_id = str(uuid.uuid4())
        result = {
            "paymentId": payment_id, "status": "ACCEPTED", "amount": body["amount"]
        }
        payments[payment_id] = {"owner": request.client_id, "response": result}
        idempotency[key] = (fingerprint, payment_id)
        response = jsonify(result)
        response.status_code = 201
        response.headers["Idempotency-Replayed"] = "false"
        return response


@app.get("/payments/<payment_id>")
@require_scope("payments.read")
def get_payment(payment_id: str):
    with _store_lock:
        record = payments.get(payment_id)
        # Do not disclose whether a payment owned by another client exists.
        if record is None or record["owner"] != request.client_id:
            return problem(404, "Not found", "payment_not_found")
        return jsonify(record["response"])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
