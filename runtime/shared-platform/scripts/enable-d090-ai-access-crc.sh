#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

oc -n keycloak-system wait --for=condition=Ready keycloak/keycloak --timeout=60s >/dev/null
oc -n tradeops wait --for=condition=Available deploy/ai-access-policy --timeout=120s >/dev/null
oc -n mayabank-api wait --for=condition=Available deploy/api-gateway --timeout=60s >/dev/null

D090_AI_ACCESS_ENABLED=true bash runtime/shared-platform/scripts/render-kong-config.sh
oc -n mayabank-api rollout restart deploy/api-gateway
oc -n mayabank-api rollout status deploy/api-gateway --timeout=300s

GW_HOST="$(oc -n mayabank-api get route api-gateway -o jsonpath='{.spec.host}')"
NO_TOKEN_CODE="$(curl -ksS -o /tmp/d090-no-token.json -w '%{http_code}'   -X POST "https://${GW_HOST}/ai/v1/chat/completions"   -H 'Content-Type: application/json'   --data '{"model":"tradeops-default","messages":[]}')"
test "${NO_TOKEN_CODE}" = "401"

rm -f /tmp/d090-no-token.json
echo "D090_KONG_AI_ROUTE=PASS"
echo "D090_KONG_NO_TOKEN_DENY=PASS"
