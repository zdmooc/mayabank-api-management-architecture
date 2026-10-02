from __future__ import annotations

import os
import uuid
from functools import wraps

import jwt
from flask import Flask, jsonify, request
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

jwks_client = PyJWKClient(JWKS_URL)
payments: dict[str, dict] = {}
idempotency: dict[str, str] = {}


def problem(status: int, title: str, code: str):
    return (
        jsonify(
            {
                "type": "about:blank",
                "title": title,
                "status": status,
                "code": code,
                "correlationId": request.headers.get("X-Correlation-ID", ""),
            }
        ),
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

            scopes = set(str(claims.get("scope", "")).split())
            if scope not in scopes:
                return problem(403, "Forbidden", "insufficient_scope")

            request.jwt_claims = claims
            return func(*args, **kwargs)

        return wrapped

    return decorator


@app.get("/health")
def health():
    return jsonify({"status": "UP"})


@app.post("/payments")
@require_scope("payments.write")
def create_payment():
    idem_key = request.headers.get("Idempotency-Key", "")
    if len(idem_key) < 16:
        return problem(400, "Invalid request", "invalid_idempotency_key")

    if idem_key in idempotency:
        payment_id = idempotency[idem_key]
        response = jsonify(payments[payment_id])
        response.status_code = 201
        response.headers["Idempotency-Replayed"] = "true"
        return response

    body = request.get_json(silent=True) or {}
    required = {"debtorAccountId", "creditorIban", "amount"}
    if not required.issubset(body):
        return problem(400, "Invalid request", "missing_fields")

    payment_id = str(uuid.uuid4())
    payment = {
        "paymentId": payment_id,
        "status": "ACCEPTED",
        "amount": body["amount"],
    }
    payments[payment_id] = payment
    idempotency[idem_key] = payment_id

    response = jsonify(payment)
    response.status_code = 201
    response.headers["Idempotency-Replayed"] = "false"
    return response


@app.get("/payments/<payment_id>")
@require_scope("payments.read")
def get_payment(payment_id: str):
    payment = payments.get(payment_id)
    if payment is None:
        return problem(404, "Not found", "payment_not_found")
    return jsonify(payment)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
