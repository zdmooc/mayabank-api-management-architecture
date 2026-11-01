#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${KEYCLOAK_EXTERNAL_URL:-http://localhost:8080}"
RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE:-120}"
ISSUER="${BASE_URL}/realms/mayabank"

REALM_JSON="$(curl -fsS "${BASE_URL}/realms/mayabank")"
PUBLIC_KEY="$(REALM_JSON="${REALM_JSON}" python3 - <<'PY'
import base64, os, textwrap, json
obj = json.loads(os.environ["REALM_JSON"])
raw = obj["public_key"].strip()
print("-----BEGIN PUBLIC KEY-----")
print("\n".join(textwrap.wrap(raw, 64)))
print("-----END PUBLIC KEY-----")
PY
)"

mkdir -p runtime/e2e/generated
ISSUER="${ISSUER}" PUBLIC_KEY="${PUBLIC_KEY}" RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE}" python3 - <<'PY'
from pathlib import Path
import os

template = Path("runtime/e2e/kong/kong.template.yml").read_text(encoding="utf-8")
issuer = os.environ["ISSUER"]
key = os.environ["PUBLIC_KEY"]
indented = "\n".join("          " + line for line in key.splitlines())

rendered = (
    template.replace("__KEYCLOAK_ISSUER__", issuer)
     .replace("__KEYCLOAK_PUBLIC_KEY_INDENTED__", indented)
    .replace("__RATE_LIMIT_PER_MINUTE__", os.environ["RATE_LIMIT_PER_MINUTE"])
)
Path("runtime/e2e/generated/kong.yml").write_text(rendered, encoding="utf-8")
print("KONG_DECLARATIVE_CONFIG_RENDER=PASS")
PY
