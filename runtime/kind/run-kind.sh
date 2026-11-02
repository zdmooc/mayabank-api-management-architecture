#!/usr/bin/env bash
# Run from Git Bash/WSL2 on Docker Desktop, or from the GitHub Actions runner.
# Prerequisites: Docker, Kind, kubectl, curl, jq, python3.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"
CLUSTER="${KIND_CLUSTER_NAME:-mayabank-api}"
NS=mayabank-api
PF_PIDS=()

cleanup() {
  for pid in "${PF_PIDS[@]}"; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
}
trap cleanup EXIT

for cmd in docker kind kubectl curl jq python3; do
  command -v "${cmd}" >/dev/null || { echo "Missing required command: ${cmd}" >&2; exit 2; }
done
kind get clusters | grep -Fxq "${CLUSTER}" || {
  echo "Create the cluster first: kind create cluster --name ${CLUSTER}" >&2
  exit 2
}
kubectl config use-context "kind-${CLUSTER}" >/dev/null

rand() { python3 -c 'import secrets; print(secrets.token_urlsafe(32))'; }
export KC_BOOTSTRAP_ADMIN_PASSWORD="${KC_BOOTSTRAP_ADMIN_PASSWORD:-$(rand)}"
export PAYMENT_CLIENT_SECRET="${PAYMENT_CLIENT_SECRET:-$(rand)}"
export READ_ONLY_CLIENT_SECRET="${READ_ONLY_CLIENT_SECRET:-$(rand)}"
export WRONG_AUDIENCE_CLIENT_SECRET="${WRONG_AUDIENCE_CLIENT_SECRET:-$(rand)}"
export UNREGISTERED_CLIENT_SECRET="${UNREGISTERED_CLIENT_SECRET:-$(rand)}"
export PARTNER_CLIENT_SECRET="${PARTNER_CLIENT_SECRET:-$(rand)}"

docker build -t mayabank-payment-api:kind runtime/e2e/payment-api
kind load docker-image mayabank-payment-api:kind --name "${CLUSTER}"
kubectl apply -f runtime/kind/manifests/core.yaml --dry-run=client >/dev/null
kubectl apply -f runtime/kind/manifests/core.yaml
kubectl -n "${NS}" create secret generic keycloak-admin \
  --from-literal=password="${KC_BOOTSTRAP_ADMIN_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "${NS}" rollout status deployment/keycloak --timeout=300s
kubectl -n "${NS}" rollout status deployment/payment-api --timeout=180s

kubectl -n "${NS}" port-forward svc/keycloak 8080:8080 > /tmp/mayabank-kind-keycloak-pf.log 2>&1 &
PF_PIDS+=("$!")
export KEYCLOAK_EXTERNAL_URL="http://localhost:8080"
bash runtime/e2e/scripts/bootstrap-keycloak.sh

export KONG_CLIENT_IDS="payment-client read-only-client wrong-audience-client partner-b-client"
bash runtime/e2e/scripts/render-kong-config.sh
kubectl -n "${NS}" create configmap kong-config \
  --from-file=kong.yml=runtime/e2e/generated/kong.yml \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl apply -f runtime/kind/manifests/kong.yaml
kubectl -n "${NS}" rollout status deployment/kong --timeout=240s

# The admin port is NOT exposed as a Service. Kubernetes port-forward targets
# pod-local port 8001 only for this controlled test process.
kubectl -n "${NS}" port-forward svc/kong-proxy 8000:8000 > /tmp/mayabank-kind-proxy-pf.log 2>&1 &
PF_PIDS+=("$!")
kubectl -n "${NS}" port-forward deployment/kong 8001:8001 > /tmp/mayabank-kind-admin-pf.log 2>&1 &
PF_PIDS+=("$!")

# Validate the actual Service and pod network listener configuration.
kubectl -n "${NS}" get svc kong-proxy -o json | python3 -c '
import json,sys
ports=[x["port"] for x in json.load(sys.stdin)["spec"]["ports"]]
assert ports == [8000], f"Unexpected Kong Service ports: {ports}"
'
echo "KIND_KONG_ADMIN_SERVICE_ISOLATED=PASS"

export KONG_PROXY_URL="http://localhost:8000"
export KONG_ADMIN_URL="http://localhost:8001"
bash runtime/e2e/scripts/test-e2e.sh

echo "MAYABANK_KIND_RUNTIME=PASS"
