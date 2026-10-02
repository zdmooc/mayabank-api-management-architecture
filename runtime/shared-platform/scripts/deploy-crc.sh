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

PAYMENT_API_EXISTED=false
if oc -n mayabank-api get deploy/payment-api >/dev/null 2>&1; then
  PAYMENT_API_EXISTED=true
fi
oc apply -f runtime/shared-platform/manifests/payment-api.yaml
if [[ "${PAYMENT_API_EXISTED}" == "true" ]]; then
  oc -n mayabank-api rollout restart deploy/payment-api
fi
if ! oc -n mayabank-api rollout status deploy/payment-api --timeout=600s; then
  echo "== Payment API rollout diagnostics"
  oc -n mayabank-api get deploy,rs,pods -o wide || true
  oc -n mayabank-api describe deploy/payment-api || true
  oc -n mayabank-api describe pods -l app=payment-api || true
  oc -n mayabank-api get events --sort-by=.lastTimestamp | tail -n 120 || true
  exit 1
fi

bash runtime/shared-platform/scripts/render-kong-config.sh
KONG_EXISTED=false
if oc -n mayabank-api get deploy/api-gateway >/dev/null 2>&1; then
  KONG_EXISTED=true
fi
oc apply -f runtime/shared-platform/manifests/kong.yaml
if [[ "${KONG_EXISTED}" == "true" ]]; then
  oc -n mayabank-api rollout restart deploy/api-gateway
fi
if ! oc -n mayabank-api rollout status deploy/api-gateway --timeout=600s; then
  echo "== Kong rollout diagnostics"
  oc -n mayabank-api get deploy,rs,pods -o wide || true
  oc -n mayabank-api describe deploy/api-gateway || true
  oc -n mayabank-api describe pods -l app=api-gateway || true
  oc -n mayabank-api get events --sort-by=.lastTimestamp | tail -n 120 || true
  exit 1
fi

oc -n mayabank-api get deploy,svc,pods,route -o wide
echo "KONG_SHARED_PLATFORM_DEPLOY=PASS"
