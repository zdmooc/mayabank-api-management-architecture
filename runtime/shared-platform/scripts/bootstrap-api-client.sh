#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${API_NAMESPACE:-mayabank-api}"
KEYCLOAK_NAMESPACE="${KEYCLOAK_NAMESPACE:-keycloak-system}"
KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps-crc.testing}"
REALM="${SHARED_REALM:-mayabank}"
ADMIN_SECRET="${KEYCLOAK_ADMIN_SECRET:-keycloak-initial-admin}"

command -v oc >/dev/null 2>&1 || { echo "oc CLI is required"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl is required"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }

ADMIN_USER="$(oc -n "${KEYCLOAK_NAMESPACE}" get secret "${ADMIN_SECRET}" -o jsonpath='{.data.username}' | base64 -d)"
ADMIN_PASSWORD="$(oc -n "${KEYCLOAK_NAMESPACE}" get secret "${ADMIN_SECRET}" -o jsonpath='{.data.password}' | base64 -d)"

ADMIN_TOKEN="$(curl -kfsS -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'client_id=admin-cli' \
  --data-urlencode 'grant_type=password' \
  --data-urlencode "username=${ADMIN_USER}" \
  --data-urlencode "password=${ADMIN_PASSWORD}" | jq -r '.access_token')"
test -n "${ADMIN_TOKEN}" && test "${ADMIN_TOKEN}" != "null"

curl -kfsS -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}" >/dev/null

admin_get() {
  curl -kfsS -H "Authorization: Bearer ${ADMIN_TOKEN}" "${KEYCLOAK_URL}$1"
}

admin_create() {
  local path="$1" data="$2" expected="${3:-201}"
  local body code
  body="$(mktemp)"
  code="$(curl -ksS -o "${body}" -w '%{http_code}' -X POST "${KEYCLOAK_URL}${path}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}" -H 'Content-Type: application/json' --data-binary "${data}")"
  if [[ "${code}" != "${expected}" ]]; then
    echo "Keycloak Admin API create failed: ${path}: HTTP ${code}" >&2
    cat "${body}" >&2
    rm -f "${body}"
    return 1
  fi
  rm -f "${body}"
}

ensure_scope() {
  local scope="$1" existing
  existing="$(admin_get "/admin/realms/${REALM}/client-scopes" | jq -r --arg n "${scope}" '.[] | select(.name==$n) | .id' | head -n1)"
  if [[ -z "${existing}" ]]; then
    admin_create "/admin/realms/${REALM}/client-scopes" "$(jq -nc --arg n "${scope}" '{name:$n,protocol:"openid-connect",attributes:{"include.in.token.scope":"true"}}')"
  fi
}

ensure_client() {
  local client_id="$1" body="$2" uuid
  uuid="$(admin_get "/admin/realms/${REALM}/clients?clientId=${client_id}" | jq -r '.[0].id // empty')"
  if [[ -z "${uuid}" ]]; then
    admin_create "/admin/realms/${REALM}/clients" "${body}"
    uuid="$(admin_get "/admin/realms/${REALM}/clients?clientId=${client_id}" | jq -r '.[0].id')"
  fi
  printf '%s' "${uuid}"
}

PAYMENT_API_UUID="$(ensure_client payment-api '{"clientId":"payment-api","enabled":true,"protocol":"openid-connect","publicClient":true,"standardFlowEnabled":false,"directAccessGrantsEnabled":false,"serviceAccountsEnabled":false}')"

for scope in payments.write payments.read; do
  ensure_scope "${scope}"
done

PAYMENT_CLIENT_UUID="$(ensure_client payment-client '{"clientId":"payment-client","enabled":true,"protocol":"openid-connect","publicClient":false,"serviceAccountsEnabled":true,"fullScopeAllowed":false,"standardFlowEnabled":false,"directAccessGrantsEnabled":false}')"

for scope in payments.write payments.read; do
  SCOPE_ID="$(admin_get "/admin/realms/${REALM}/client-scopes" | jq -r --arg n "${scope}" '.[] | select(.name==$n) | .id')"
  code="$(curl -ksS -o /tmp/api-scope-link.out -w '%{http_code}' -X PUT \
    "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${PAYMENT_CLIENT_UUID}/default-client-scopes/${SCOPE_ID}" \
    -H "Authorization: Bearer ${ADMIN_TOKEN}")"
  [[ "${code}" == "204" ]] || { echo "scope link ${scope} failed: HTTP ${code}" >&2; exit 1; }
done

MAPPER_ID="$(admin_get "/admin/realms/${REALM}/clients/${PAYMENT_CLIENT_UUID}/protocol-mappers/models" | jq -r '.[] | select(.name=="payment-api-audience") | .id' | head -n1)"
if [[ -z "${MAPPER_ID}" ]]; then
  admin_create "/admin/realms/${REALM}/clients/${PAYMENT_CLIENT_UUID}/protocol-mappers/models" '{"name":"payment-api-audience","protocol":"openid-connect","protocolMapper":"oidc-audience-mapper","config":{"included.client.audience":"payment-api","access.token.claim":"true"}}'
fi

CLIENT_SECRET="$(curl -kfsS -X POST \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${PAYMENT_CLIENT_UUID}/client-secret" | jq -r '.value')"
test -n "${CLIENT_SECRET}" && test "${CLIENT_SECRET}" != "null"

oc -n "${NAMESPACE}" create secret generic payment-client-secret \
  --from-literal=client-secret="${CLIENT_SECRET}" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null

unset ADMIN_TOKEN ADMIN_USER ADMIN_PASSWORD CLIENT_SECRET
rm -f /tmp/api-scope-link.out

echo "API_SHARED_KEYCLOAK_CLIENT=PASS"
