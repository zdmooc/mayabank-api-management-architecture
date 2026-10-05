#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

NAMESPACE="${API_NAMESPACE:-mayabank-api}"
DEPLOY="${KONG_DEPLOYMENT:-api-gateway}"
BACKUP="$(mktemp)"

cleanup() {
  rm -f "${BACKUP}" /tmp/d090-no-token.json
}
trap cleanup EXIT

oc -n keycloak-system wait --for=condition=Ready keycloak/keycloak --timeout=60s >/dev/null
oc -n tradeops wait --for=condition=Available deploy/ai-access-policy --timeout=120s >/dev/null
oc -n "${NAMESPACE}" wait --for=condition=Available "deploy/${DEPLOY}" --timeout=120s >/dev/null

# Save the last known-good declarative config before enabling /ai.
oc -n "${NAMESPACE}" get cm kong-config -o jsonpath='{.data.kong\.yml}' > "${BACKUP}"

D090_AI_ACCESS_ENABLED=true bash runtime/shared-platform/scripts/render-kong-config.sh

# Validate the rendered DB-less configuration with the same Kong image before restart.
KONG_IMAGE="$(oc -n "${NAMESPACE}" get deploy "${DEPLOY}" -o jsonpath='{.spec.template.spec.containers[0].image}')"
TMP_CM="d090-kong-validate-$(date +%s)"
oc -n "${NAMESPACE}" create configmap "${TMP_CM}"   --from-file=kong.yml=<(oc -n "${NAMESPACE}" get cm kong-config -o jsonpath='{.data.kong\.yml}')   >/dev/null
oc -n "${NAMESPACE}" run d090-kong-config-check --rm -i --restart=Never   --image="${KONG_IMAGE}"   --overrides="$(python3 - "${TMP_CM}" <<'PY'
import json, sys
cm=sys.argv[1]
print(json.dumps({
  "spec":{
    "automountServiceAccountToken":False,
    "containers":[{
      "name":"check",
      "image":"PLACEHOLDER",
      "command":["sh","-ec","kong config parse /kong/declarative/kong.yml >/dev/null && echo D090_KONG_CONFIG_PARSE=PASS"],
      "volumeMounts":[{"name":"config","mountPath":"/kong/declarative","readOnly":True}],
      "securityContext":{"allowPrivilegeEscalation":False,"capabilities":{"drop":["ALL"]},"runAsNonRoot":True}
    }],
    "volumes":[{"name":"config","configMap":{"name":cm}}]
  }
}))
PY
)"   --command -- sh -ec 'kong config parse /kong/declarative/kong.yml >/dev/null && echo D090_KONG_CONFIG_PARSE=PASS'
oc -n "${NAMESPACE}" delete cm "${TMP_CM}" --ignore-not-found >/dev/null

oc -n "${NAMESPACE}" rollout restart "deploy/${DEPLOY}"

if ! oc -n "${NAMESPACE}" rollout status "deploy/${DEPLOY}" --timeout=600s; then
  echo "D090_KONG_ROLLOUT=FAIL" >&2
  echo "===== KONG DIAGNOSTICS =====" >&2
  oc -n "${NAMESPACE}" get deploy,rs,pods -l app=api-gateway -o wide >&2 || true
  oc -n "${NAMESPACE}" describe deploy "${DEPLOY}" >&2 || true
  oc -n "${NAMESPACE}" describe pods -l app=api-gateway >&2 || true
  oc -n "${NAMESPACE}" logs -l app=api-gateway --tail=200 --prefix >&2 || true
  oc -n "${NAMESPACE}" get events --sort-by=.lastTimestamp | tail -n 120 >&2 || true

  echo "===== RESTORING LAST KNOWN-GOOD KONG CONFIG =====" >&2
  oc -n "${NAMESPACE}" create configmap kong-config     --from-file=kong.yml="${BACKUP}"     --dry-run=client -o yaml | oc apply -f - >/dev/null
  oc -n "${NAMESPACE}" rollout restart "deploy/${DEPLOY}" >/dev/null
  oc -n "${NAMESPACE}" rollout status "deploy/${DEPLOY}" --timeout=600s || true
  exit 1
fi

echo "D090_KONG_ROLLOUT=PASS"

GW_HOST="$(oc -n "${NAMESPACE}" get route api-gateway -o jsonpath='{.spec.host}')"
NO_TOKEN_CODE="$(curl -ksS -o /tmp/d090-no-token.json -w '%{http_code}'   -X POST "https://${GW_HOST}/ai/v1/chat/completions"   -H 'Content-Type: application/json'   --data '{"model":"tradeops-default","messages":[]}')"
test "${NO_TOKEN_CODE}" = "401"

echo "D090_KONG_AI_ROUTE=PASS"
echo "D090_KONG_NO_TOKEN_DENY=PASS"
