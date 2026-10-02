#!/usr/bin/env bash
set -euo pipefail

: "${PAYMENT_CLIENT_SECRET:?set PAYMENT_CLIENT_SECRET}"

KC_URL="${KEYCLOAK_EXTERNAL_URL:-http://localhost:8080}"
GW_URL="${KONG_PROXY_URL:-http://localhost:8000}"

for _ in $(seq 1 90); do
  if curl -fsS "${GW_URL}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -fsS "${GW_URL}/health" | jq -e '.status == "UP"' >/dev/null
echo "API_HEALTH_VIA_KONG=PASS"

NO_TOKEN_CODE="$(curl -sS -o /tmp/no-token.json -w '%{http_code}'   -X POST "${GW_URL}/payments"   -H 'Content-Type: application/json'   -H 'Idempotency-Key: 1111111111111111'   --data '{"debtorAccountId":"D1","creditorIban":"FR761234567890","amount":{"value":"10.00","currency":"EUR"}}')"

test "${NO_TOKEN_CODE}" = "401"
echo "KONG_JWT_MISSING_REJECTED=PASS"

TOKEN_RESPONSE="$(curl -fsS -X POST "${KC_URL}/realms/mayabank/protocol/openid-connect/token"   -H 'Content-Type: application/x-www-form-urlencoded'   --data-urlencode 'client_id=payment-client'   --data-urlencode "client_secret=${PAYMENT_CLIENT_SECRET}"   --data-urlencode 'grant_type=client_credentials')"

TOKEN="$(TOKEN_RESPONSE="${TOKEN_RESPONSE}" python3 - <<'PY'
import json, os
obj=json.loads(os.environ["TOKEN_RESPONSE"])
token=obj.get("access_token")
assert token
print(token)
PY
)"
test -n "${TOKEN}"

TOKEN_RESPONSE="${TOKEN_RESPONSE}" python3 - <<'PY'
import base64, json, os
token=json.loads(os.environ["TOKEN_RESPONSE"])["access_token"]
payload=token.split(".")[1]
payload += "=" * (-len(payload) % 4)
claims=json.loads(base64.urlsafe_b64decode(payload))
assert claims["iss"] == "http://localhost:8080/realms/mayabank"
assert "payment-api" in (claims.get("aud") if isinstance(claims.get("aud"), list) else [claims.get("aud")])
scopes=set(claims.get("scope","").split())
assert {"payments.write","payments.read"}.issubset(scopes)
PY
echo "KEYCLOAK_CLIENT_CREDENTIALS_SCOPE_AUDIENCE=PASS"

PAYLOAD='{"debtorAccountId":"D1","creditorIban":"FR761234567890","amount":{"value":"10.00","currency":"EUR"}}'
IDEM="e2e-idempotency-0001"

curl -fsS -D /tmp/create-headers.txt -o /tmp/create.json   -X POST "${GW_URL}/payments"   -H "Authorization: Bearer ${TOKEN}"   -H 'Content-Type: application/json'   -H "Idempotency-Key: ${IDEM}"   --data "${PAYLOAD}"

PAYMENT_ID="$(jq -r '.paymentId' /tmp/create.json)"
test -n "${PAYMENT_ID}" && test "${PAYMENT_ID}" != "null"
grep -qi '^X-Correlation-ID:' /tmp/create-headers.txt
grep -qi '^Idempotency-Replayed: false' /tmp/create-headers.txt
echo "KONG_KEYCLOAK_PAYMENT_CREATE=PASS"
echo "KONG_CORRELATION_ID=PASS"

curl -fsS -D /tmp/replay-headers.txt -o /tmp/replay.json   -X POST "${GW_URL}/payments"   -H "Authorization: Bearer ${TOKEN}"   -H 'Content-Type: application/json'   -H "Idempotency-Key: ${IDEM}"   --data "${PAYLOAD}"

test "$(jq -r '.paymentId' /tmp/replay.json)" = "${PAYMENT_ID}"
grep -qi '^Idempotency-Replayed: true' /tmp/replay-headers.txt
echo "PAYMENT_IDEMPOTENCY_REPLAY=PASS"

curl -fsS "${GW_URL}/payments/${PAYMENT_ID}"   -H "Authorization: Bearer ${TOKEN}"   | jq -e --arg id "${PAYMENT_ID}" '.paymentId == $id and .status == "ACCEPTED"' >/dev/null
echo "PAYMENT_READ_SCOPE=PASS"

BAD_TOKEN="${TOKEN%?}x"
BAD_CODE="$(curl -sS -o /tmp/bad-token.json -w '%{http_code}'   "${GW_URL}/payments/${PAYMENT_ID}"   -H "Authorization: Bearer ${BAD_TOKEN}")"
test "${BAD_CODE}" = "401"
echo "KONG_INVALID_SIGNATURE_REJECTED=PASS"

unset TOKEN TOKEN_RESPONSE
echo "API_MANAGEMENT_E2E_RUNTIME=PASS"
