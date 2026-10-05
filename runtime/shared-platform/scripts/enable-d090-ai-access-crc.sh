#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

NAMESPACE="${API_NAMESPACE:-mayabank-api}"
DEPLOY="${KONG_DEPLOYMENT:-api-gateway}"
ADMIN_LOCAL_PORT="${KONG_ADMIN_LOCAL_PORT:-18001}"
BACKUP="$(mktemp)"
RENDERED="$(mktemp)"
PF_LOG="$(mktemp)"
PF_PID=""

cleanup() {
  if [[ -n "${PF_PID}" ]]; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
    wait "${PF_PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${BACKUP}" "${RENDERED}" "${PF_LOG}" /tmp/d090-no-token.json /tmp/d090-kong-admin.json
}
trap cleanup EXIT

oc -n keycloak-system wait --for=condition=Ready keycloak/keycloak --timeout=60s >/dev/null
oc -n tradeops wait --for=condition=Available deploy/ai-access-policy --timeout=120s >/dev/null
oc -n "${NAMESPACE}" wait --for=condition=Available "deploy/${DEPLOY}" --timeout=120s >/dev/null

# Save the last known-good declarative configuration.
oc -n "${NAMESPACE}" get cm kong-config -o jsonpath='{.data.kong\.yml}' > "${BACKUP}"

# Render the opt-in /ai service into the canonical Kong ConfigMap.
D090_AI_ACCESS_ENABLED=true bash runtime/shared-platform/scripts/render-kong-config.sh
oc -n "${NAMESPACE}" get cm kong-config -o jsonpath='{.data.kong\.yml}' > "${RENDERED}"

# Use the internal Admin API through a local port-forward. This avoids replacing
# the Kong pod on the constrained single-node CRC. The ConfigMap remains the
# persisted source for the next normal pod restart.
oc -n "${NAMESPACE}" port-forward svc/api-gateway "${ADMIN_LOCAL_PORT}:8001" >"${PF_LOG}" 2>&1 &
PF_PID="$!"

ADMIN_READY=false
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${ADMIN_LOCAL_PORT}/status" >/dev/null 2>&1; then
    ADMIN_READY=true
    break
  fi
  sleep 1
done
if [[ "${ADMIN_READY}" != "true" ]]; then
  cat "${PF_LOG}" >&2 || true
  echo "D090_KONG_ADMIN_PORT_FORWARD=FAIL" >&2
  exit 1
fi
echo "D090_KONG_ADMIN_PORT_FORWARD=PASS"

reload_config() {
  local cfg="$1" body code
  body="$(mktemp)"
  code="$(curl -sS -o "${body}" -w '%{http_code}'     -X POST "http://127.0.0.1:${ADMIN_LOCAL_PORT}/config"     -F "config=@${cfg};type=text/yaml")"
  cat "${body}" > /tmp/d090-kong-admin.json
  rm -f "${body}"
  [[ "${code}" == "200" || "${code}" == "201" ]]
}

if ! reload_config "${RENDERED}"; then
  echo "D090_KONG_HOT_RELOAD=FAIL" >&2
  cat /tmp/d090-kong-admin.json >&2 || true
  oc -n "${NAMESPACE}" create configmap kong-config     --from-file=kong.yml="${BACKUP}"     --dry-run=client -o yaml | oc apply -f - >/dev/null
  reload_config "${BACKUP}" >/dev/null 2>&1 || true
  exit 1
fi
echo "D090_KONG_HOT_RELOAD=PASS"

GW_HOST="$(oc -n "${NAMESPACE}" get route api-gateway -o jsonpath='{.spec.host}')"
NO_TOKEN_CODE="$(curl -ksS -o /tmp/d090-no-token.json -w '%{http_code}'   -X POST "https://${GW_HOST}/ai/v1/chat/completions"   -H 'Content-Type: application/json'   --data '{"model":"tradeops-default","messages":[]}')"

if [[ "${NO_TOKEN_CODE}" != "401" ]]; then
  echo "D090_KONG_NO_TOKEN_DENY=FAIL http=${NO_TOKEN_CODE}" >&2
  cat /tmp/d090-no-token.json >&2 || true
  echo "===== ROLLBACK CANONICAL KONG CONFIG =====" >&2
  oc -n "${NAMESPACE}" create configmap kong-config     --from-file=kong.yml="${BACKUP}"     --dry-run=client -o yaml | oc apply -f - >/dev/null
  reload_config "${BACKUP}" >/dev/null 2>&1 || true
  exit 1
fi

echo "D090_KONG_AI_ROUTE=PASS"
echo "D090_KONG_NO_TOKEN_DENY=PASS"
echo "D090_G1A_KONG=PASS"
