#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

if ! oc api-resources --api-group=config.openshift.io --no-headers 2>/dev/null | grep -qE '^clusterversions[[:space:]]'; then
  echo "ERROR: current context is not OpenShift/CRC" >&2
  exit 2
fi

oc -n shared-observability wait --for=condition=Available deploy/otel-collector --timeout=60s
oc -n keycloak-system wait --for=condition=Ready keycloak/keycloak --timeout=60s
oc -n mayabank-api wait --for=condition=Available deploy/payment-api --timeout=60s

bash runtime/shared-platform/scripts/render-kong-config.sh

oc apply -f runtime/shared-platform/manifests/kong.yaml

if ! oc -n mayabank-api rollout status deploy/api-gateway --timeout=600s; then
  echo "== Kong rollout diagnostics"
  oc -n mayabank-api get deploy,rs,pods,route -o wide || true
  oc -n mayabank-api describe deploy/api-gateway || true
  oc -n mayabank-api describe pods -l app=api-gateway || true
  oc -n mayabank-api get events --sort-by=.lastTimestamp | tail -n 120 || true
  exit 1
fi

oc -n mayabank-api get deploy/api-gateway,pods,svc,route -o wide
echo "KONG_SHARED_PLATFORM_DEPLOY=PASS"
