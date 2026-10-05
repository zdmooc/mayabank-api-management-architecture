#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

NAMESPACE="${API_NAMESPACE:-mayabank-api}"
DEPLOY="${KONG_DEPLOYMENT:-api-gateway}"
ADMIN_LOCAL_PORT="${KONG_ADMIN_LOCAL_PORT:-18001}"

BASELINE="$(mktemp)"
RENDERED="$(mktemp)"
PF_LOG="$(mktemp)"
PF_PID=""

cleanup() {
  if [[ -n "${PF_PID}" ]]; then
    kill "${PF_PID}" >/dev/null 2>&1 || true
    wait "${PF_PID}" >/dev/null 2>&1 || true
  fi
  rm -f "${BASELINE}" "${RENDERED}" "${PF_LOG}"     /tmp/d090-no-token.json /tmp/d090-kong-admin.json
}
trap cleanup EXIT

diag_kong() {
  echo "===== KONG DIAGNOSTICS =====" >&2
  oc -n "${NAMESPACE}" get deploy,rs,pods -l app=api-gateway -o wide >&2 || true
  oc -n "${NAMESPACE}" describe deploy "${DEPLOY}" >&2 || true
  oc -n "${NAMESPACE}" describe pods -l app=api-gateway >&2 || true
  oc -n "${NAMESPACE}" logs -l app=api-gateway --tail=200 --prefix >&2 || true
  oc -n "${NAMESPACE}" logs -l app=api-gateway --previous --tail=200 --prefix >&2 || true
  oc -n "${NAMESPACE}" get events --sort-by=.lastTimestamp | tail -n 120 >&2 || true
}

oc -n keycloak-system wait --for=condition=Ready keycloak/keycloak --timeout=60s >/dev/null
oc -n tradeops wait --for=condition=Available deploy/ai-access-policy --timeout=120s >/dev/null

# Always render the known-good baseline from Git. This avoids trusting a ConfigMap
# that may have been left with an unproven D-090 extension after a failed restart.
D090_AI_ACCESS_ENABLED=false KONG_CONFIG_OUTPUT_FILE="${BASELINE}"   bash runtime/shared-platform/scripts/render-kong-config.sh

# If Kong is currently unhealthy, recover it first with the baseline config.
if ! oc -n "${NAMESPACE}" wait --for=condition=Available "deploy/${DEPLOY}" --timeout=10s >/dev/null 2>&1; then
  echo "D090_KONG_RECOVERY=START"
  oc -n "${NAMESPACE}" create configmap kong-config     --from-file=kong.yml="${BASELINE}"     --dry-run=client -o yaml | oc apply -f - >/dev/null
  oc apply -f runtime/shared-platform/manifests/kong.yaml >/dev/null
  oc -n "${NAMESPACE}" rollout restart "deploy/${DEPLOY}" >/dev/null
  if ! oc -n "${NAMESPACE}" rollout status "deploy/${DEPLOY}" --timeout=600s; then
    diag_kong
    echo "D090_KONG_RECOVERY=FAIL" >&2
    exit 1
  fi
  echo "D090_KONG_RECOVERY=PASS"
else
  echo "D090_KONG_RECOVERY=NOT_NEEDED"
fi

# Render the candidate /ai config to a file only. Do NOT persist it yet.
D090_AI_ACCESS_ENABLED=true KONG_CONFIG_OUTPUT_FILE="${RENDERED}"   bash runtime/shared-platform/scripts/render-kong-config.sh

# Reach Kong Admin API without exposing it as an OpenShift Route.
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

# Kong itself parses/validates the declarative candidate before we persist it.
if ! reload_config "${RENDERED}"; then
  echo "D090_KONG_HOT_RELOAD=FAIL" >&2
  cat /tmp/d090-kong-admin.json >&2 || true
  reload_config "${BASELINE}" >/dev/null 2>&1 || true
  exit 1
fi
echo "D090_KONG_HOT_RELOAD=PASS"

GW_HOST="$(oc -n "${NAMESPACE}" get route api-gateway -o jsonpath='{.spec.host}')"
NO_TOKEN_CODE="$(curl -ksS -o /tmp/d090-no-token.json -w '%{http_code}'   -X POST "https://${GW_HOST}/ai/v1/chat/completions"   -H 'Content-Type: application/json'   --data '{"model":"tradeops-default","messages":[]}')"

if [[ "${NO_TOKEN_CODE}" != "401" ]]; then
  echo "D090_KONG_NO_TOKEN_DENY=FAIL http=${NO_TOKEN_CODE}" >&2
  cat /tmp/d090-no-token.json >&2 || true
  reload_config "${BASELINE}" >/dev/null 2>&1 || true
  echo "D090_KONG_HOT_ROLLBACK=PASS" >&2
  exit 1
fi

echo "D090_KONG_AI_ROUTE=PASS"
echo "D090_KONG_NO_TOKEN_DENY=PASS"

# Only after the runtime candidate passed do we persist it for future restarts.
oc -n "${NAMESPACE}" create configmap kong-config   --from-file=kong.yml="${RENDERED}"   --dry-run=client -o yaml | oc apply -f - >/dev/null

echo "D090_KONG_CONFIG_PERSIST=PASS"
echo "D090_G1A_KONG=PASS"
