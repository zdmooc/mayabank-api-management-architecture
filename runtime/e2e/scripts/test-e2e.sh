#!/usr/bin/env bash
set -euo pipefail

: "${PAYMENT_CLIENT_SECRET:?set PAYMENT_CLIENT_SECRET}"
: "${READ_ONLY_CLIENT_SECRET:?set READ_ONLY_CLIENT_SECRET}"
: "${WRONG_AUDIENCE_CLIENT_SECRET:?set WRONG_AUDIENCE_CLIENT_SECRET}"
: "${UNREGISTERED_CLIENT_SECRET:?set UNREGISTERED_CLIENT_SECRET}"
: "${PARTNER_CLIENT_SECRET:?set PARTNER_CLIENT_SECRET}"

KC_URL="${KEYCLOAK_EXTERNAL_URL:-http://localhost:8080}"
GW_URL="${KONG_PROXY_URL:-http://localhost:8000}"
KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"

# Synthetic data only. FR1420041010050500013M02606 is a published sample IBAN
# with a valid mod-97 checksum; ...M02607 is the same IBAN with a broken one.
PAYLOAD='{"debtorAccountId":"D1","creditorIban":"FR1420041010050500013M02606","amount":{"value":"10.00","currency":"EUR"}}'
PAYLOAD_OTHER_AMOUNT='{"debtorAccountId":"D1","creditorIban":"FR1420041010050500013M02606","amount":{"value":"999.00","currency":"EUR"}}'
PAYLOAD_BAD_IBAN='{"debtorAccountId":"D1","creditorIban":"FR1420041010050500013M02607","amount":{"value":"10.00","currency":"EUR"}}'

# get_token <client_id> <client_secret>
get_token() {
  local response
  response="$(curl -fsS -X POST "${KC_URL}/realms/mayabank/protocol/openid-connect/token" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=$1" \
    --data-urlencode "client_secret=$2" \
    --data-urlencode 'grant_type=client_credentials')"
  TOKEN_RESPONSE="${response}" python3 -c 'import json,os; t=json.loads(os.environ["TOKEN_RESPONSE"]).get("access_token"); assert t; print(t)'
}

# http_code <output file> <curl args...>
http_code() {
  local out="$1"
  shift
  curl -sS -o "${out}" -w '%{http_code}' "$@"
}

for _ in $(seq 1 90); do
  if curl -fsS "${KONG_ADMIN_URL}/status" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -fsS "${KONG_ADMIN_URL}/status" >/dev/null
echo "KONG_ADMIN_READY=PASS"

# --- Gateway authentication ---------------------------------------------------

NO_TOKEN_CODE="$(http_code /tmp/no-token.json -X POST "${GW_URL}/payments" \
  -H 'Content-Type: application/json' -H 'Idempotency-Key: 1111111111111111' --data "${PAYLOAD}")"
test "${NO_TOKEN_CODE}" = "401"
echo "KONG_JWT_MISSING_REJECTED=PASS"

TOKEN="$(get_token payment-client "${PAYMENT_CLIENT_SECRET}")"
TOKEN="${TOKEN}" python3 - <<'PY'
import base64, json, os
payload = os.environ["TOKEN"].split(".")[1]
payload += "=" * (-len(payload) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload))
assert claims["iss"] == "http://localhost:8080/realms/mayabank"
aud = claims.get("aud") if isinstance(claims.get("aud"), list) else [claims.get("aud")]
assert "payment-api" in aud
assert claims.get("azp") == "payment-client"
assert {"payments.write", "payments.read"}.issubset(set(claims.get("scope", "").split()))
PY
echo "KEYCLOAK_CLIENT_CREDENTIALS_SCOPE_AUDIENCE=PASS"

UNREGISTERED_TOKEN="$(get_token unregistered-client "${UNREGISTERED_CLIENT_SECRET}")"
UNREGISTERED_CODE="$(http_code /tmp/unregistered.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${UNREGISTERED_TOKEN}" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: unregistered-client-0001' --data "${PAYLOAD}")"
test "${UNREGISTERED_CODE}" = "401"
echo "KONG_UNREGISTERED_CLIENT_REJECTED=PASS"

# --- Nominal flow + idempotency -----------------------------------------------

IDEM="e2e-idempotency-0001"

curl -fsS -D /tmp/create-headers.txt -o /tmp/create.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: ${IDEM}" --data "${PAYLOAD}"

PAYMENT_ID="$(jq -r '.paymentId' /tmp/create.json)"
test -n "${PAYMENT_ID}" && test "${PAYMENT_ID}" != "null"
grep -qi '^X-Correlation-ID:' /tmp/create-headers.txt
grep -qi '^Idempotency-Replayed: false' /tmp/create-headers.txt
echo "KONG_KEYCLOAK_PAYMENT_CREATE=PASS"
echo "KONG_CORRELATION_ID=PASS"

curl -fsS -D /tmp/replay-headers.txt -o /tmp/replay.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: ${IDEM}" --data "${PAYLOAD}"

test "$(jq -r '.paymentId' /tmp/replay.json)" = "${PAYMENT_ID}"
grep -qi '^Idempotency-Replayed: true' /tmp/replay-headers.txt
echo "PAYMENT_IDEMPOTENCY_REPLAY=PASS"

MISMATCH_CODE="$(http_code /tmp/idem-mismatch.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: ${IDEM}" --data "${PAYLOAD_OTHER_AMOUNT}")"
test "${MISMATCH_CODE}" = "422"
jq -e '.code == "idempotency_key_reused"' /tmp/idem-mismatch.json >/dev/null
echo "PAYMENT_IDEMPOTENCY_KEY_REUSE_REJECTED=PASS"

# Cross-client creation with SAME idempotency key, and mutual read isolation.
PARTNER_TOKEN="$(get_token partner-b-client "${PARTNER_CLIENT_SECRET}")"
curl -fsS -o /tmp/partner-create.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${PARTNER_TOKEN}" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: ${IDEM}" --data "${PAYLOAD}"
PARTNER_PAYMENT_ID="$(jq -r '.paymentId' /tmp/partner-create.json)"
test -n "${PARTNER_PAYMENT_ID}" && test "${PARTNER_PAYMENT_ID}" != "null"
test "${PARTNER_PAYMENT_ID}" != "${PAYMENT_ID}"
OTHER_READ_CODE="$(http_code /tmp/partner-bola.json "${GW_URL}/payments/${PAYMENT_ID}" -H "Authorization: Bearer ${PARTNER_TOKEN}")"
SELF_READ_CODE="$(http_code /tmp/owner-bola.json "${GW_URL}/payments/${PARTNER_PAYMENT_ID}" -H "Authorization: Bearer ${TOKEN}")"
test "${OTHER_READ_CODE}" = "404"
test "${SELF_READ_CODE}" = "404"
echo "PAYMENT_TWO_WRITERS_ISOLATED=PASS"


BAD_IBAN_CODE="$(http_code /tmp/bad-iban.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: e2e-bad-iban-0001' --data "${PAYLOAD_BAD_IBAN}")"
test "${BAD_IBAN_CODE}" = "422"
jq -e '.code == "invalid_creditor_iban"' /tmp/bad-iban.json >/dev/null
echo "PAYMENT_IBAN_CHECKSUM_REJECTED=PASS"

curl -fsS "${GW_URL}/payments/${PAYMENT_ID}" -H "Authorization: Bearer ${TOKEN}" \
  | jq -e --arg id "${PAYMENT_ID}" '.paymentId == $id and .status == "ACCEPTED"' >/dev/null
echo "PAYMENT_READ_SCOPE=PASS"

# --- Authorization -----------------------------------------------------------

READ_ONLY_TOKEN="$(get_token read-only-client "${READ_ONLY_CLIENT_SECRET}")"
READ_ONLY_CODE="$(http_code /tmp/read-only.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${READ_ONLY_TOKEN}" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: read-only-idempotency-0001' --data "${PAYLOAD}")"
test "${READ_ONLY_CODE}" = "403"
echo "PAYMENT_INSUFFICIENT_SCOPE_REJECTED=PASS"

# OWASP API1: valid token + read scope, but the payment belongs to another client.
BOLA_CODE="$(http_code /tmp/bola.json "${GW_URL}/payments/${PAYMENT_ID}" \
  -H "Authorization: Bearer ${READ_ONLY_TOKEN}")"
test "${BOLA_CODE}" = "404"
echo "PAYMENT_BOLA_OTHER_CLIENT_REJECTED=PASS"

WRONG_AUD_TOKEN="$(get_token wrong-audience-client "${WRONG_AUDIENCE_CLIENT_SECRET}")"
WRONG_AUD_CODE="$(http_code /tmp/wrong-audience.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${WRONG_AUD_TOKEN}" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: wrong-audience-0001' --data "${PAYLOAD}")"
test "${WRONG_AUD_CODE}" = "401"
echo "PAYMENT_WRONG_AUDIENCE_REJECTED=PASS"

# --- Resource consumption -------------------------------------------------------

python3 - <<'PY' >/tmp/oversized-payment.json
import json
print(json.dumps({
  "debtorAccountId": "D1",
  "creditorIban": "FR1420041010050500013M02606",
  "amount": {"value": "10.00", "currency": "EUR"},
  "padding": "x" * 1100000
}))
PY
OVERSIZE_CODE="$(http_code /tmp/oversized-response.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H 'Idempotency-Key: oversized-idempotency-0001' --data-binary @/tmp/oversized-payment.json)"
test "${OVERSIZE_CODE}" = "413"
echo "KONG_REQUEST_SIZE_LIMIT=PASS"

RATE_LIMIT_SEEN=0
for _ in $(seq 1 30); do
  code="$(http_code /tmp/rate-limit.json "${GW_URL}/payments/${PAYMENT_ID}" -H "Authorization: Bearer ${TOKEN}")"
  if [[ "${code}" == "429" ]]; then
    RATE_LIMIT_SEEN=1
    break
  fi
  test "${code}" = "200"
done
test "${RATE_LIMIT_SEEN}" = "1"
echo "KONG_RATE_LIMIT_429=PASS"

# Another consumer is not throttled by payment-client's exhausted budget.
ISOLATION_CODE="$(http_code /tmp/isolation.json "${GW_URL}/payments/${PAYMENT_ID}" \
  -H "Authorization: Bearer ${READ_ONLY_TOKEN}")"
test "${ISOLATION_CODE}" = "404"
echo "KONG_RATE_LIMIT_PER_CONSUMER_ISOLATION=PASS"

# Alter the FIRST character of the signature segment: it carries 6 significant
# bits, whereas the last base64url character may only differ in padding bits
# (same decoded signature, so the token would still be valid).
BAD_TOKEN="$(TOKEN="${TOKEN}" python3 -c 'import os; h,p,s=os.environ["TOKEN"].split("."); print(".".join([h,p,("B" if s[0]=="A" else "A")+s[1:]]))')"
BAD_CODE="$(http_code /tmp/bad-token.json "${GW_URL}/payments/${PAYMENT_ID}" -H "Authorization: Bearer ${BAD_TOKEN}")"
test "${BAD_CODE}" = "401"
echo "KONG_INVALID_SIGNATURE_REJECTED=PASS"

unset TOKEN READ_ONLY_TOKEN WRONG_AUD_TOKEN UNREGISTERED_TOKEN PARTNER_TOKEN
echo "API_MANAGEMENT_E2E_RUNTIME=PASS"
