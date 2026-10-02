#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${API_NAMESPACE:-mayabank-api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps-crc.testing}"
REALM="${SHARED_REALM:-mayabank}"

CLIENT_SECRET="$(oc -n "${NAMESPACE}" get secret payment-client-secret -o jsonpath='{.data.client-secret}' | base64 -d)"
test -n "${CLIENT_SECRET}"

TOKEN_RESPONSE="$(curl -kfsS -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'client_id=payment-client' \
  --data-urlencode "client_secret=${CLIENT_SECRET}" \
  --data-urlencode 'grant_type=client_credentials')"

TOKEN="$(TOKEN_RESPONSE="${TOKEN_RESPONSE}" python3 - <<'PY'
import json,os
t=json.loads(os.environ["TOKEN_RESPONSE"]).get("access_token")
assert t
print(t)
PY
)"

TOKEN_RESPONSE="${TOKEN_RESPONSE}" python3 - <<'PY'
import base64,json,os
t=json.loads(os.environ["TOKEN_RESPONSE"])["access_token"]
p=t.split(".")[1]; p += "="*(-len(p)%4)
c=json.loads(base64.urlsafe_b64decode(p))
assert c["iss"]=="https://keycloak.apps-crc.testing/realms/mayabank"
aud=c.get("aud"); aud=aud if isinstance(aud,list) else [aud]
assert "payment-api" in aud
s=set(c.get("scope","").split())
assert {"payments.write","payments.read"}.issubset(s)
PY
echo "API_SHARED_OIDC_TOKEN=PASS"

GW_HOST="$(oc -n "${NAMESPACE}" get route api-gateway -o jsonpath='{.spec.host}')"
GW_URL="https://${GW_HOST}"

NO_TOKEN_CODE="$(curl -ksS -o /tmp/shared-no-token.json -w '%{http_code}' -X POST "${GW_URL}/payments" \
  -H 'Content-Type: application/json' -H 'Idempotency-Key: shared-no-token-0001' \
  --data '{"debtorAccountId":"D1","creditorIban":"FR761234567890","amount":{"value":"10.00","currency":"EUR"}}')"
test "${NO_TOKEN_CODE}" = "401"

TRACE_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PAYLOAD='{"debtorAccountId":"D1","creditorIban":"FR761234567890","amount":{"value":"10.00","currency":"EUR"}}'
IDEM="shared-crc-idempotency-0001"
curl -kfsS -D /tmp/shared-create-headers.txt -o /tmp/shared-create.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: ${IDEM}" --data "${PAYLOAD}"
PAYMENT_ID="$(jq -r '.paymentId' /tmp/shared-create.json)"
test -n "${PAYMENT_ID}" && test "${PAYMENT_ID}" != "null"
grep -qi '^X-Correlation-ID:' /tmp/shared-create-headers.txt

curl -kfsS "${GW_URL}/payments/${PAYMENT_ID}" -H "Authorization: Bearer ${TOKEN}" \
  | jq -e --arg id "${PAYMENT_ID}" '.paymentId==$id and .status=="ACCEPTED"' >/dev/null
echo "API_SHARED_GATEWAY_PAYMENT=PASS"

sleep 8
TRACE_LOG="$(oc -n shared-observability logs deploy/otel-collector --since-time="${TRACE_START}" 2>/dev/null || true)"
if ! printf '%s\n' "${TRACE_LOG}" | grep -Eq 'Traces|ResourceSpans|Span #'; then
  echo "ERROR: no trace export observed in shared OTel collector after Kong request" >&2
  exit 1
fi
echo "KONG_SHARED_OTEL_TRACE=PASS"

unset TOKEN TOKEN_RESPONSE CLIENT_SECRET
rm -f /tmp/shared-no-token.json /tmp/shared-create-headers.txt /tmp/shared-create.json
echo "API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS"
