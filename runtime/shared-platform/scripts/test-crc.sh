#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${API_NAMESPACE:-mayabank-api}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps-crc.testing}"
REALM="${SHARED_REALM:-mayabank}"

# Fail closed unless a trusted CA bundle is provided. Insecure TLS is an
# explicit local-only opt-out, never recorded as a TLS-validation proof.
if [[ -n "${CRC_CA_BUNDLE:-}" ]]; then
  test -r "${CRC_CA_BUNDLE}" || { echo "Unreadable CRC_CA_BUNDLE" >&2; exit 2; }
  TLS_ARGS=(--cacert "${CRC_CA_BUNDLE}")
  echo "CRC_TLS_CERT_VERIFICATION=ENABLED"
elif [[ "${CRC_ALLOW_INSECURE_TLS:-false}" == "true" ]]; then
  TLS_ARGS=(-k)
  echo "CRC_TLS_CERT_VERIFICATION=NOT_PROVEN (explicit insecure lab mode)" >&2
else
  echo "Set CRC_CA_BUNDLE to the trusted router CA PEM (or explicitly opt out with CRC_ALLOW_INSECURE_TLS=true for an unverified lab run)" >&2
  exit 2
fi


CLIENT_SECRET="$(oc -n "${NAMESPACE}" get secret payment-client-secret -o jsonpath='{.data.client-secret}' | base64 -d)"
test -n "${CLIENT_SECRET}"

TOKEN_RESPONSE="$(curl "${TLS_ARGS[@]}" -fsS -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
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

NO_TOKEN_CODE="$(curl "${TLS_ARGS[@]}" -sS -o /tmp/shared-no-token.json -w '%{http_code}' -X POST "${GW_URL}/payments" \
  -H 'Content-Type: application/json' -H 'Idempotency-Key: shared-no-token-0001' \
  --data '{"debtorAccountId":"D1","creditorIban":"FR7630006000011234567890189","amount":{"value":"10.00","currency":"EUR"}}')"
test "${NO_TOKEN_CODE}" = "401"

TRACE_START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TRACE_ID="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
SPAN_ID="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
TRACE_PARENT="00-${TRACE_ID}-${SPAN_ID}-01"

PAYLOAD='{"debtorAccountId":"D1","creditorIban":"FR7630006000011234567890189","amount":{"value":"10.00","currency":"EUR"}}'
IDEM="shared-crc-idempotency-0001"
curl "${TLS_ARGS[@]}" -fsS -D /tmp/shared-create-headers.txt -o /tmp/shared-create.json -X POST "${GW_URL}/payments" \
  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
  -H "Idempotency-Key: ${IDEM}" -H "traceparent: ${TRACE_PARENT}" --data "${PAYLOAD}"
PAYMENT_ID="$(jq -r '.paymentId' /tmp/shared-create.json)"
test -n "${PAYMENT_ID}" && test "${PAYMENT_ID}" != "null"
grep -qi '^X-Correlation-ID:' /tmp/shared-create-headers.txt

curl "${TLS_ARGS[@]}" -fsS "${GW_URL}/payments/${PAYMENT_ID}" -H "Authorization: Bearer ${TOKEN}" \
  | jq -e --arg id "${PAYMENT_ID}" '.paymentId==$id and .status=="ACCEPTED"' >/dev/null
echo "API_SHARED_GATEWAY_PAYMENT=PASS"

sleep 8
TRACE_LOG="$(oc -n shared-observability logs deploy/otel-collector --since-time="${TRACE_START}" 2>/dev/null || true)"
if ! printf '%s\n' "${TRACE_LOG}" | grep -qi "${TRACE_ID}"; then
  echo "ERROR: no trace export observed in shared OTel collector after Kong request" >&2
  exit 1
fi
echo "KONG_SHARED_OTEL_TRACE_ID=PASS"
echo "KONG_SHARED_OTEL_TRACE=PASS"

unset TOKEN TOKEN_RESPONSE CLIENT_SECRET
rm -f /tmp/shared-no-token.json /tmp/shared-create-headers.txt /tmp/shared-create.json
echo "API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS"
