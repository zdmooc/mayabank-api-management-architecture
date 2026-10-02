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

PAYMENT_CPU="$(oc -n mayabank-api get pod -l app=payment-api -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}')"
echo "PAYMENT_API_CPU_REQUEST=${PAYMENT_CPU}"
test "${PAYMENT_CPU}" = "10m"

echo "== Re-render and restart Kong after CPU headroom release"
bash runtime/shared-platform/scripts/render-kong-config.sh
oc apply -f runtime/shared-platform/manifests/kong.yaml
oc -n mayabank-api rollout restart deploy/api-gateway
oc -n mayabank-api rollout status deploy/api-gateway --timeout=600s

KONG_CPU="$(oc -n mayabank-api get pod -l app=api-gateway -o jsonpath='{.items[0].spec.containers[0].resources.requests.cpu}')"
echo "KONG_CPU_REQUEST=${KONG_CPU}"
test "${KONG_CPU}" = "25m"

oc -n mayabank-api get deploy,pods,svc,route -o wide

echo "== CRC constrained recovery: final allocation"
oc describe node crc | sed -n '/Allocated resources:/,/Events:/p' || true

echo "CRC_CONSTRAINED_API_RECOVERY=PASS"
echo "KONG_SHARED_PLATFORM_DEPLOY=PASS"
