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
TMP_POD="d090-kong-config-check"
TMP_CFG="$(mktemp)"
oc -n "${NAMESPACE}" get cm kong-config -o jsonpath='{.data.kong\.yml}' > "${TMP_CFG}"
oc -n "${NAMESPACE}" create configmap "${TMP_CM}"   --from-file=kong.yml="${TMP_CFG}" >/dev/null
rm -f "${TMP_CFG}"

oc -n "${NAMESPACE}" delete pod "${TMP_POD}" --ignore-not-found >/dev/null
cat <<EOF | oc -n "${NAMESPACE}" apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: ${TMP_POD}
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  securityContext:
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: check
      image: ${KONG_IMAGE}
      command: ["sh", "-ec"]
      args:
        - kong config parse /kong/declarative/kong.yml >/dev/null && echo D090_KONG_CONFIG_PARSE=PASS
      volumeMounts:
        - name: config
          mountPath: /kong/declarative
          readOnly: true
      resources:
        requests: {cpu: 10m, memory: 64Mi}
        limits: {cpu: 250m, memory: 256Mi}
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: ["ALL"]
        runAsNonRoot: true
  volumes:
    - name: config
      configMap:
        name: ${TMP_CM}
EOF

if ! oc -n "${NAMESPACE}" wait --for=condition=Ready "pod/${TMP_POD}" --timeout=180s >/dev/null 2>&1; then
  oc -n "${NAMESPACE}" get pod "${TMP_POD}" -o wide >&2 || true
  oc -n "${NAMESPACE}" describe pod "${TMP_POD}" >&2 || true
fi
if ! oc -n "${NAMESPACE}" wait --for=jsonpath='{.status.phase}'=Succeeded "pod/${TMP_POD}" --timeout=180s >/dev/null; then
  oc -n "${NAMESPACE}" logs "${TMP_POD}" >&2 || true
  oc -n "${NAMESPACE}" delete pod "${TMP_POD}" --ignore-not-found >/dev/null
  oc -n "${NAMESPACE}" delete cm "${TMP_CM}" --ignore-not-found >/dev/null
  echo "D090_KONG_CONFIG_PARSE=FAIL" >&2
  exit 1
fi
oc -n "${NAMESPACE}" logs "${TMP_POD}"
oc -n "${NAMESPACE}" delete pod "${TMP_POD}" --ignore-not-found >/dev/null
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
