#!/usr/bin/env bash
set -euo pipefail

: "${KC_BOOTSTRAP_ADMIN_PASSWORD:?set KC_BOOTSTRAP_ADMIN_PASSWORD}"
: "${PAYMENT_CLIENT_SECRET:?set PAYMENT_CLIENT_SECRET}"
: "${READ_ONLY_CLIENT_SECRET:?set READ_ONLY_CLIENT_SECRET}"
: "${WRONG_AUDIENCE_CLIENT_SECRET:?set WRONG_AUDIENCE_CLIENT_SECRET}"

BASE_URL="${KEYCLOAK_EXTERNAL_URL:-http://localhost:8080}"

for _ in $(seq 1 120); do
  if curl -fsS "${BASE_URL}/realms/master/.well-known/openid-configuration" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

ADMIN_TOKEN="$(curl -fsS -X POST "${BASE_URL}/realms/master/protocol/openid-connect/token"   -H 'Content-Type: application/x-www-form-urlencoded'   --data-urlencode 'client_id=admin-cli'   --data-urlencode 'grant_type=password'   --data-urlencode 'username=e2e-admin'   --data-urlencode "password=${KC_BOOTSTRAP_ADMIN_PASSWORD}" | jq -r '.access_token')"

test -n "${ADMIN_TOKEN}" && test "${ADMIN_TOKEN}" != "null"

admin_json() {
  local method="$1"
  local path="$2"
  local data="$3"
  local expected="${4:-201}"
  local body_file
  body_file="$(mktemp)"
  local code

  code="$(curl -sS -o "${body_file}" -w '%{http_code}'     -X "${method}" "${BASE_URL}${path}"     -H "Authorization: Bearer ${ADMIN_TOKEN}"     -H 'Content-Type: application/json'     --data-binary "${data}")"

  if [[ "${code}" != "${expected}" ]]; then
    echo "Keycloak Admin API failure: ${method} ${path}: expected ${expected}, got ${code}" >&2
    cat "${body_file}" >&2
    rm -f "${body_file}"
    return 1
  fi
  rm -f "${body_file}"
}

admin_get() {
  curl -fsS     -H "Authorization: Bearer ${ADMIN_TOKEN}"     "${BASE_URL}$1"
}

admin_json POST /admin/realms   '{"realm":"mayabank","enabled":true,"registrationAllowed":false}'

admin_json POST /admin/realms/mayabank/clients   '{"clientId":"payment-api","enabled":true,"protocol":"openid-connect","publicClient":true,"standardFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":false}'

for scope in payments.write payments.read; do
  SCOPE_NAME="${scope}" python3 - <<'PY' >/tmp/client-scope.json
import json, os
print(json.dumps({
    "name": os.environ["SCOPE_NAME"],
    "protocol": "openid-connect",
    "attributes": {"include.in.token.scope": "true"},
}))
PY
  admin_json POST /admin/realms/mayabank/client-scopes "$(cat /tmp/client-scope.json)"
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
    "fullScopeAllowed": False,
    "standardFlowEnabled": False,
    "directAccessGrantsEnabled": False
}))
PY

admin_json POST /admin/realms/mayabank/clients "$(cat /tmp/payment-client.json)"

PAYMENT_CLIENT_UUID="$(admin_get '/admin/realms/mayabank/clients?clientId=payment-client' | jq -r '.[0].id')"
test -n "${PAYMENT_CLIENT_UUID}" && test "${PAYMENT_CLIENT_UUID}" != "null"

for scope in payments.write payments.read; do
  SCOPE_ID="$(admin_get '/admin/realms/mayabank/client-scopes'     | jq -r --arg n "${scope}" '.[] | select(.name == $n) | .id')"
  test -n "${SCOPE_ID}" && test "${SCOPE_ID}" != "null"

  code="$(curl -sS -o /tmp/scope-link.out -w '%{http_code}'     -X PUT "${BASE_URL}/admin/realms/mayabank/clients/${PAYMENT_CLIENT_UUID}/default-client-scopes/${SCOPE_ID}"     -H "Authorization: Bearer ${ADMIN_TOKEN}")"
  if [[ "${code}" != "204" ]]; then
    echo "Failed to link client scope ${scope}: HTTP ${code}" >&2
    cat /tmp/scope-link.out >&2
    exit 1
  fi
done

admin_json POST "/admin/realms/mayabank/clients/${PAYMENT_CLIENT_UUID}/protocol-mappers/models"   '{
    "name":"payment-api-audience",
    "protocol":"openid-connect",
    "protocolMapper":"oidc-audience-mapper",
    "config":{
      "included.client.audience":"payment-api",
      "access.token.claim":"true"
    }
  }'


READ_ONLY_SECRET="${READ_ONLY_CLIENT_SECRET}" python3 - <<'PY' >/tmp/read-only-client.json
import json, os
print(json.dumps({
    "clientId": "read-only-client",
    "enabled": True,
    "protocol": "openid-connect",
    "publicClient": False,
    "secret": os.environ["READ_ONLY_SECRET"],
    "serviceAccountsEnabled": True,
    "fullScopeAllowed": False,
    "standardFlowEnabled": False,
    "directAccessGrantsEnabled": False
}))
PY
admin_json POST /admin/realms/mayabank/clients "$(cat /tmp/read-only-client.json)"
READ_ONLY_UUID="$(admin_get '/admin/realms/mayabank/clients?clientId=read-only-client' | jq -r '.[0].id')"
READ_SCOPE_ID="$(admin_get '/admin/realms/mayabank/client-scopes' | jq -r '.[] | select(.name == "payments.read") | .id')"
code="$(curl -sS -o /tmp/read-scope-link.out -w '%{http_code}' -X PUT "${BASE_URL}/admin/realms/mayabank/clients/${READ_ONLY_UUID}/default-client-scopes/${READ_SCOPE_ID}" -H "Authorization: Bearer ${ADMIN_TOKEN}")"
test "${code}" = "204"
admin_json POST "/admin/realms/mayabank/clients/${READ_ONLY_UUID}/protocol-mappers/models" '{
  "name":"payment-api-audience",
  "protocol":"openid-connect",
  "protocolMapper":"oidc-audience-mapper",
  "config":{"included.client.audience":"payment-api","access.token.claim":"true"}
}'

WRONG_AUD_SECRET="${WRONG_AUDIENCE_CLIENT_SECRET}" python3 - <<'PY' >/tmp/wrong-audience-client.json
import json, os
print(json.dumps({
    "clientId": "wrong-audience-client",
    "enabled": True,
    "protocol": "openid-connect",
    "publicClient": False,
    "secret": os.environ["WRONG_AUD_SECRET"],
    "serviceAccountsEnabled": True,
    "fullScopeAllowed": False,
    "standardFlowEnabled": False,
    "directAccessGrantsEnabled": False
}))
PY
admin_json POST /admin/realms/mayabank/clients "$(cat /tmp/wrong-audience-client.json)"
WRONG_AUD_UUID="$(admin_get '/admin/realms/mayabank/clients?clientId=wrong-audience-client' | jq -r '.[0].id')"
for scope in payments.write payments.read; do
  SCOPE_ID="$(admin_get '/admin/realms/mayabank/client-scopes' | jq -r --arg n "${scope}" '.[] | select(.name == $n) | .id')"
  code="$(curl -sS -o /tmp/wrong-scope-link.out -w '%{http_code}' -X PUT "${BASE_URL}/admin/realms/mayabank/clients/${WRONG_AUD_UUID}/default-client-scopes/${SCOPE_ID}" -H "Authorization: Bearer ${ADMIN_TOKEN}")"
  test "${code}" = "204"
done

unset ADMIN_TOKEN
echo "KEYCLOAK_E2E_BOOTSTRAP=PASS"
