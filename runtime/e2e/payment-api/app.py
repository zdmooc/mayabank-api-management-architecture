"""MayaBank Payment API fixture.

Lab-only resource server used behind Kong. It enforces, in the backend, the
controls that gateway authentication cannot provide on its own:

- token validation (issuer, audience, signature, expiry) and scope checks;
- object-level authorization (OWASP API1): a payment is visible only to the
  client application that created it;
- idempotency scoped per client and bound to the request payload;
- request validation aligned with ``apis/openapi/payment-api.yaml``.

State is in memory: this is a test fixture, not a payment system.
"""

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
from flask import Flask, g, jsonify, request
from jwt import PyJWKClient

app = Flask(__name__)

EXPECTED_ISSUER = os.environ.get(
    "OIDC_EXPECTED_ISSUER",
    "http://localhost:8080/realms/mayabank",
)
JWKS_URL = os.environ.get(
    "OIDC_JWKS_URL",
    "http://keycloak:8080/realms/mayabank/protocol/openid-connect/certs",
)
AUDIENCE = os.environ.get("OIDC_AUDIENCE", "payment-api")

IDEMPOTENCY_KEY_MIN = 16
IDEMPOTENCY_KEY_MAX = 128

AMOUNT_PATTERN = re.compile(r"^[0-9]+(\.[0-9]{1,2})?$")
CURRENCY_PATTERN = re.compile(r"^[A-Z]{3}$")
IBAN_PATTERN = re.compile(r"^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$")
ACCOUNT_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
# Supported country lengths for this bounded banking lab, not a worldwide IBAN registry.
IBAN_LENGTHS = {"FR": 27, "DE": 22, "GB": 22, "BE": 16, "NL": 18,
                "ES": 24, "IT": 27, "CH": 21, "AT": 20, "LU": 20,
                "PT": 25, "IE": 22, "PL": 28}
SUPPORTED_CURRENCIES = {"EUR", "USD", "GBP", "CHF", "CAD", "JPY"}

REQUEST_FIELDS = {"debtorAccountId", "creditorIban", "amount"}
MONEY_FIELDS = {"value", "currency"}

jwks_client = PyJWKClient(JWKS_URL)

# paymentId -> {"owner": client_id, "resource": public representation}
payments: dict[str, dict] = {}
# (client_id, idempotency key) -> {"paymentId": ..., "requestHash": ...}
idempotency: dict[tuple[str, str], dict] = {}
state_lock = threading.Lock()


def problem(status: int, title: str, code: str, detail: str | None = None):
    body = {
        "type": "about:blank",
        "title": title,
        "status": status,
        "code": code,
        "correlationId": request.headers.get("X-Correlation-ID", ""),
    }
    if detail:
        body["detail"] = detail
    return jsonify(body), status, {"Content-Type": "application/problem+json"}


def require_scope(scope: str):
    def decorator(func):
        @wraps(func)
        def wrapped(*args, **kwargs):
            auth = request.headers.get("Authorization", "")
            if not auth.startswith("Bearer "):
                return problem(401, "Unauthorized", "missing_token")

            token = auth.removeprefix("Bearer ").strip()
            try:
                signing_key = jwks_client.get_signing_key_from_jwt(token)
                claims = jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=["RS256"],
                    audience=AUDIENCE,
                    issuer=EXPECTED_ISSUER,
                    options={"require": ["exp", "iss"]},
                )
            except Exception:
                return problem(401, "Unauthorized", "invalid_token")

            # Client application identity. Keycloak sets `azp` on
            # client_credentials tokens; `client_id` is the RFC 9068 claim.
            client_id = claims.get("azp") or claims.get("client_id")
            if not isinstance(client_id, str) or not client_id:
                return problem(401, "Unauthorized", "missing_client_identity")

            scopes = set(str(claims.get("scope", "")).split())
            if scope not in scopes:
                return problem(403, "Forbidden", "insufficient_scope")

            g.jwt_claims = claims
            g.client_id = client_id
            return func(*args, **kwargs)

        return wrapped

    return decorator


def iban_checksum_valid(iban: str) -> bool:
    """ISO 13616 mod-97 check."""
    rearranged = iban[4:] + iban[:4]
    digits = "".join(str(int(ch, 36)) for ch in rearranged)
    return int(digits) % 97 == 1


def validate_payment_request(body) -> tuple[int, str, str] | None:
    """Return (status, code, detail) on error, None when valid."""
    if not isinstance(body, dict):
        return 400, "invalid_body", "request body must be a JSON object"

    missing = REQUEST_FIELDS - body.keys()
    if missing:
        return 400, "missing_fields", "missing: " + ", ".join(sorted(missing))
    unknown = body.keys() - REQUEST_FIELDS
    if unknown:
        return 400, "unknown_fields", "unknown: " + ", ".join(sorted(unknown))

    debtor = body["debtorAccountId"]
    if not isinstance(debtor, str) or not ACCOUNT_ID_PATTERN.fullmatch(debtor):
        return 400, "invalid_debtor_account", "debtorAccountId has an invalid format"

    amount = body["amount"]
    if not isinstance(amount, dict) or amount.keys() != MONEY_FIELDS:
        return 400, "invalid_amount", "amount must contain exactly value and currency"
    if not isinstance(amount["value"], str) or not AMOUNT_PATTERN.fullmatch(amount["value"]):
        return 400, "invalid_amount", "amount.value must be a decimal string"
    if not isinstance(amount["currency"], str) or not CURRENCY_PATTERN.fullmatch(amount["currency"]):
        return 400, "invalid_currency", "amount.currency must be an ISO 4217 code"
    try:
        value = Decimal(amount["value"])
    except InvalidOperation:
        return 400, "invalid_amount", "amount.value must be a valid decimal"
    if not value.is_finite() or not (Decimal('0') < value <= Decimal('1000000000')):
        return 422, "invalid_amount", "amount.value must be greater than zero"

    if amount["currency"] not in SUPPORTED_CURRENCIES:
        return 422, "invalid_currency", "currency is not supported by this lab"

    iban = body["creditorIban"]
    if not isinstance(iban, str) or not IBAN_PATTERN.fullmatch(iban):
        return 400, "invalid_creditor_iban", "creditorIban has an invalid format"
    # Format and modulo 97 alone do NOT guarantee the country's IBAN length.
    expected_length = IBAN_LENGTHS.get(iban[:2])
    if expected_length is None or len(iban) != expected_length:
        return 400, "invalid_creditor_iban", "unsupported IBAN country or incorrect country length"
    if not iban_checksum_valid(iban):
        return 422, "invalid_creditor_iban", "creditorIban checksum is invalid"

    return None


def request_fingerprint(body: dict) -> str:
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def payment_response(resource: dict, replayed: bool):
    response = jsonify(resource)
    response.status_code = 201
    response.headers["Idempotency-Replayed"] = "true" if replayed else "false"
    return response


@app.get("/health")
def health():
    return jsonify({"status": "UP"})


@app.post("/payments")
@require_scope("payments.write")
def create_payment():
    idem_key = request.headers.get("Idempotency-Key", "")
    if not IDEMPOTENCY_KEY_MIN <= len(idem_key) <= IDEMPOTENCY_KEY_MAX:
        return problem(400, "Invalid request", "invalid_idempotency_key")

    body = request.get_json(silent=True)
    error = validate_payment_request(body)
    if error:
        status, code, detail = error
        title = "Invalid request" if status == 400 else "Unprocessable request"
        return problem(status, title, code, detail)

    fingerprint = request_fingerprint(body)
    scope_key = (g.client_id, idem_key)

    with state_lock:
        previous = idempotency.get(scope_key)
        if previous is not None:
            if previous["requestHash"] != fingerprint:
                return problem(
                    422,
                    "Unprocessable request",
                    "idempotency_key_reused",
                    "Idempotency-Key already used with a different payload",
                )
            return payment_response(payments[previous["paymentId"]]["resource"], True)

        payment_id = str(uuid.uuid4())
        resource = {
            "paymentId": payment_id,
            "status": "ACCEPTED",
            "amount": body["amount"],
        }
        payments[payment_id] = {"owner": g.client_id, "resource": resource}
        idempotency[scope_key] = {"paymentId": payment_id, "requestHash": fingerprint}

    return payment_response(resource, False)


@app.get("/payments/<payment_id>")
@require_scope("payments.read")
def get_payment(payment_id: str):
    record = payments.get(payment_id)
    # Same answer for "does not exist" and "not yours": no existence oracle.
    if record is None or record["owner"] != g.client_id:
        return problem(404, "Not found", "payment_not_found")
    return jsonify(record["resource"])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
