#!/usr/bin/env bash
set -euo pipefail

: "${KC_BOOTSTRAP_ADMIN_PASSWORD:?set KC_BOOTSTRAP_ADMIN_PASSWORD}"
: "${PAYMENT_CLIENT_SECRET:?set PAYMENT_CLIENT_SECRET}"

BASE_URL="${KEYCLOAK_EXTERNAL_URL:-http://localhost:8080}"

for _ in $(seq 1 120); do
  if curl -fsS "${BASE_URL}/realms/master/.well-known/openid-configuration" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

ADMIN_TOKEN="$(curl -fsS -X POST "${BASE_URL}/realms/master/protocol/openid-connect/token"   -H 'Content-Type: application/x-www-form-urlencoded'   --data-urlencode 'client_id=admin-cli'   --data-urlencode 'grant_type=password'   --data-urlencode 'username=e2e-admin'   --data-urlencode "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" | jq -r '.access_token')"

test -n "${ADMIN_TOKEN}" && test "${ADMIN_TOKEN}" != "null"

api() {
  curl -fsS     -H "Authorization: Bearer ${ADMIN_TOKEN}"     -H 'Content-Type: application/json'     "$@"
}

curl -fsS -o /dev/null -w '%{http_code}'   -X POST "${BASE_URL}/admin/realms"   -H "Authorization: Bearer ${ADMIN_TOKEN}"   -H 'Content-Type: application/json'   --data '{"realm":"mayabank","enabled":true,"registrationAllowed":false}'   | grep -qx '201'

api -X POST "${BASE_URL}/admin/realms/mayabank/clients"   --data '{"clientId":"payment-api","enabled":true,"protocol":"openid-connect","bearerOnly":true}'

for scope in payments.write payments.read; do
  api -X POST "${BASE_URL}/admin/realms/mayabank/client-scopes"     --data "{"name":"${scope}","protocol":"openid-connect"}"
done

PAYMENT_SECRET="${PAYMENT_CLIENT_SECRET}" python3 - <<'PY' >/tmp/payment-client.json
import json, os
print(json.dumps({
    "clientId": "payment-client",
    "enabled": True,
    "protocol": "openid-connect",
    "publicClient": False,
    "secret": os.environ["PAYMENT_SECRET"],
    "serviceAccountsEnabled": True,
    "standardFlowEnabled": False,
    "directAccessGrantsEnabled": False
}))
PY

api -X POST "${BASE_URL}/admin/realms/mayabank/clients"   --data-binary @/tmp/payment-client.json

PAYMENT_CLIENT_UUID="$(api "${BASE_URL}/admin/realms/mayabank/clients?clientId=payment-client" | jq -r '.[0].id')"
test -n "${PAYMENT_CLIENT_UUID}" && test "${PAYMENT_CLIENT_UUID}" != "null"

for scope in payments.write payments.read; do
  SCOPE_ID="$(api "${BASE_URL}/admin/realms/mayabank/client-scopes"     | jq -r --arg n "${scope}" '.[] | select(.name == $n) | .id')"
  test -n "${SCOPE_ID}" && test "${SCOPE_ID}" != "null"
  curl -fsS -o /dev/null     -X PUT "${BASE_URL}/admin/realms/mayabank/clients/${PAYMENT_CLIENT_UUID}/default-client-scopes/${SCOPE_ID}"     -H "Authorization: Bearer ${ADMIN_TOKEN}"
done

api -X POST "${BASE_URL}/admin/realms/mayabank/clients/${PAYMENT_CLIENT_UUID}/protocol-mappers/models"   --data '{
    "name":"payment-api-audience",
    "protocol":"openid-connect",
    "protocolMapper":"oidc-audience-mapper",
    "config":{
      "included.client.audience":"payment-api",
      "access.token.claim":"true"
    }
  }'

unset ADMIN_TOKEN
echo "KEYCLOAK_E2E_BOOTSTRAP=PASS"
