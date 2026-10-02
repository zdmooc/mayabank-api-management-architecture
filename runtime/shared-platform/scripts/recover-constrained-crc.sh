#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

if ! oc api-resources --api-group=config.openshift.io --no-headers 2>/dev/null | grep -qE '^clusterversions[[:space:]]'; then
  echo "ERROR: current context is not OpenShift/CRC" >&2
  exit 2
fi

echo "== CRC constrained recovery: current allocation"
oc describe node crc | sed -n '/Allocated resources:/,/Events:/p' || true

echo "== Apply compact Payment API CRC request"
oc apply -f runtime/shared-platform/manifests/payment-api.yaml
oc -n mayabank-api rollout status deploy/payment-api --timeout=600s

DEPLOY_PAYMENT_CPU="$(oc -n mayabank-api get deploy/payment-api -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')"
echo "PAYMENT_API_DEPLOYMENT_CPU_REQUEST=${DEPLOY_PAYMENT_CPU}"
test "${DEPLOY_PAYMENT_CPU}" = "10m"

PAYMENT_POD=""
for _ in $(seq 1 60); do
  PAYMENT_POD="$(oc -n mayabank-api get pods -l app=payment-api --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
    | awk '$2=="10m" && $3=="true"{print $1; exit}')"
  if [[ -n "${PAYMENT_POD}" ]]; then
    break
  fi
  sleep 2
done

if [[ -z "${PAYMENT_POD}" ]]; then
  echo "ERROR: no Ready payment-api pod with 10m CPU request was observed" >&2
  oc -n mayabank-api get pods -l app=payment-api \
    -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,CPU:.spec.containers[0].resources.requests.cpu
  exit 1
fi

PAYMENT_CPU="$(oc -n mayabank-api get "pod/${PAYMENT_POD}" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')"
echo "PAYMENT_API_READY_POD=${PAYMENT_POD}"
echo "PAYMENT_API_CPU_REQUEST=${PAYMENT_CPU}"
test "${PAYMENT_CPU}" = "10m"

echo "== Re-render and restart Kong after CPU headroom release"
bash runtime/shared-platform/scripts/render-kong-config.sh
oc apply -f runtime/shared-platform/manifests/kong.yaml
oc -n mayabank-api rollout restart deploy/api-gateway
if ! oc -n mayabank-api rollout status deploy/api-gateway --timeout=600s; then
  echo "== Kong recovery diagnostics"
  oc -n mayabank-api get deploy,rs,pods,svc,route -o wide || true
  oc -n mayabank-api describe deploy/api-gateway || true
  oc -n mayabank-api describe pods -l app=api-gateway || true
  KONG_DIAG_POD="$(oc -n mayabank-api get pods -l app=api-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [[ -n "${KONG_DIAG_POD}" ]]; then
    echo "== Kong current logs"
    oc -n mayabank-api logs "${KONG_DIAG_POD}" --tail=200 || true
    echo "== Kong previous logs"
    oc -n mayabank-api logs "${KONG_DIAG_POD}" --previous --tail=200 || true
  fi
  echo "== Node allocation"
  oc describe node crc | sed -n '/Allocated resources:/,/Events:/p' || true
  echo "== Recent namespace events"
  oc -n mayabank-api get events --sort-by=.lastTimestamp | tail -n 160 || true
  exit 1
fi

DEPLOY_KONG_CPU="$(oc -n mayabank-api get deploy/api-gateway -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}')"
echo "KONG_DEPLOYMENT_CPU_REQUEST=${DEPLOY_KONG_CPU}"
test "${DEPLOY_KONG_CPU}" = "25m"

KONG_POD="$(oc -n mayabank-api get pods -l app=api-gateway --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].resources.requests.cpu}{"\t"}{.status.containerStatuses[0].ready}{"\n"}{end}' \
  | awk '$2=="25m" && $3=="true"{print $1; exit}')"
test -n "${KONG_POD}"
KONG_CPU="$(oc -n mayabank-api get "pod/${KONG_POD}" -o jsonpath='{.spec.containers[0].resources.requests.cpu}')"
echo "KONG_READY_POD=${KONG_POD}"
echo "KONG_CPU_REQUEST=${KONG_CPU}"
test "${KONG_CPU}" = "25m"

oc -n mayabank-api get deploy,pods,svc,route -o wide

echo "== CRC constrained recovery: final allocation"
oc describe node crc | sed -n '/Allocated resources:/,/Events:/p' || true

echo "CRC_CONSTRAINED_API_RECOVERY=PASS"
echo "KONG_SHARED_PLATFORM_DEPLOY=PASS"
