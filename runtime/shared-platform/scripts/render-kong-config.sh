#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps-crc.testing}"
REALM="${SHARED_REALM:-mayabank}"
OTEL_TRACES_ENDPOINT="${OTEL_TRACES_ENDPOINT:-http://otel-collector.shared-observability.svc:4318/v1/traces}"
ISSUER="${KEYCLOAK_URL}/realms/${REALM}"
D090_AI_ACCESS_ENABLED="${D090_AI_ACCESS_ENABLED:-false}"

REALM_JSON="$(curl -kfsS "${KEYCLOAK_URL}/realms/${REALM}")"
PUBLIC_KEY="$(REALM_JSON="${REALM_JSON}" python3 - <<'PY'
import json, os, textwrap
obj=json.loads(os.environ["REALM_JSON"])
raw=obj["public_key"].strip()
print("-----BEGIN PUBLIC KEY-----")
print("\n".join(textwrap.wrap(raw,64)))
print("-----END PUBLIC KEY-----")
PY
)"

OUT="$(mktemp)"
ISSUER="${ISSUER}" PUBLIC_KEY="${PUBLIC_KEY}" OTEL_TRACES_ENDPOINT="${OTEL_TRACES_ENDPOINT}" D090_AI_ACCESS_ENABLED="${D090_AI_ACCESS_ENABLED}" python3 - <<'PY' > "${OUT}"
from pathlib import Path
import os
template=Path("runtime/shared-platform/kong/kong.template.yml").read_text(encoding="utf-8")
key=os.environ["PUBLIC_KEY"]
indented="\n".join("          "+line for line in key.splitlines())
d090 = ""
if os.environ.get("D090_AI_ACCESS_ENABLED","false").lower() == "true":
    d090 = """  - name: ai-access-policy
    url: http://ai-access-policy.tradeops.svc:8020
    routes:
      - name: ai-chat-completions
        paths:
          - /ai
        strip_path: true
    plugins:
      - name: correlation-id
        config:
          header_name: X-Correlation-ID
          generator: uuid
          echo_downstream: true
      - name: rate-limiting
        config:
          minute: 180
          policy: local
      - name: request-size-limiting
        config:
          allowed_payload_size: 2
          size_unit: megabytes
      - name: jwt
        config:
          key_claim_name: iss
          claims_to_verify:
            - exp
"""
rendered=(template
  .replace("__KEYCLOAK_ISSUER__",os.environ["ISSUER"])
  .replace("__KEYCLOAK_PUBLIC_KEY_INDENTED__",indented)
  .replace("__OTEL_TRACES_ENDPOINT__",os.environ["OTEL_TRACES_ENDPOINT"])
  .replace("__D090_AI_ACCESS_SERVICE__",d090))
print(rendered,end="")
PY

if [[ -n "${KONG_CONFIG_OUTPUT_FILE:-}" ]]; then
  cp "${OUT}" "${KONG_CONFIG_OUTPUT_FILE}"
  rm -f "${OUT}"
  echo "KONG_SHARED_CONFIG_RENDER=PASS mode=file"
else
  oc -n mayabank-api create configmap kong-config --from-file=kong.yml="${OUT}" --dry-run=client -o yaml | oc apply -f - >/dev/null
  rm -f "${OUT}"
  echo "KONG_SHARED_CONFIG_RENDER=PASS mode=configmap"
fi
