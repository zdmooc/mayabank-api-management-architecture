#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "${ROOT_DIR}"

KEYCLOAK_URL="${KEYCLOAK_URL:-https://keycloak.apps-crc.testing}"
REALM="${SHARED_REALM:-mayabank}"
OTEL_TRACES_ENDPOINT="${OTEL_TRACES_ENDPOINT:-http://otel-collector.shared-observability.svc:4318/v1/traces}"
ISSUER="${KEYCLOAK_URL}/realms/${REALM}"

REAlM_JSON=""
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
ISSUER="${ISSUER}" PUBLIC_KEY="${PUBLIC_KEY}" OTEL_TRACES_ENDPOINT="${OTEL_TRACES_ENDPOINT}" python3 - "${OUT}" <<'PY'
from pathlib import Path
import os, sys
template=Path("runtime/shared-platform/kong/kong.template.yml").read_text(encoding="utf-8")
key=os.environ["PUBLIC_KEY"]
indented="\n".join("          "+line for line in key.splitlines())
rendered=(template
  .replace("__KEYCLOAK_ISSUER__",os.environ["ISSUER"])
  .replace("__KEYCLOAK_PUBLIC_KEY_INDENTED__",indented)
  .replace("__OTEL_TRACES_ENDPOINT__",os.environ["OTEL_TRACES_ENDPOINT"]))
Path(sys.argv[1]).write_text(rendered,encoding="utf-8")
PY

oc -n mayabank-api create configmap kong-config --from-file=kong.yml="${OUT}" --dry-run=client -o yaml | oc apply -f - >/dev/null
rm -f "${OUT}"
echo "KONG_SHARED_CONFIG_RENDER=PASS"
