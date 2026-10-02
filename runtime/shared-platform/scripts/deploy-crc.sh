#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

if ! oc api-resources --api-group=config.openshift.io --no-headers 2>/dev/null | grep -qE '^clusterversions[[:space:]]'; then
  echo "ERROR: current context is not OpenShift/CRC" >&2
  exit 2
fi

oc get clusterversion version
oc -n shared-observability get deploy otel-collector
oc -n shared-observability wait --for=condition=Available deploy/otel-collector --timeout=60s
oc -n keycloak-system wait --for=condition=Ready keycloak/keycloak --timeout=60s
curl -kfsS https://keycloak.apps-crc.testing/realms/mayabank/.well-known/openid-configuration >/dev/null

oc apply -f runtime/shared-platform/manifests/namespace.yaml
bash runtime/shared-platform/scripts/bootstrap-api-client.sh

oc apply -f runtime/shared-platform/manifests/payment-api-build.yaml
oc -n mayabank-api start-build payment-api --from-dir=runtime/e2e/payment-api --follow --wait
echo "PAYMENT_API_BUILD=PASS"

oc apply -f runtime/shared-platform/manifests/payment-api.yaml
oc -n mayabank-api rollout restart deploy/payment-api >/dev/null 2>&1 || true
oc -n mayabank-api rollout status deploy/payment-api --timeout=600s

bash runtime/shared-platform/scripts/render-kong-config.sh
oc apply -f runtime/shared-platform/manifests/kong.yaml
oc -n mayabank-api rollout restart deploy/api-gateway >/dev/null 2>&1 || true
oc -n mayabank-api rollout status deploy/api-gateway --timeout=600s

oc -n mayabank-api get deploy,svc,pods,route -o wide
echo "KONG_SHARED_PLATFORM_DEPLOY=PASS"
