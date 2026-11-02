#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${KEYCLOAK_EXTERNAL_URL:-http://localhost:8080}"
RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE:-120}"
# Client applications onboarded at the gateway (one Kong consumer each).
# `unregistered-client` exists in Keycloak but is deliberately NOT listed.
KONG_CLIENT_IDS="${KONG_CLIENT_IDS:-payment-client read-only-client wrong-audience-client}"

REALM_JSON="$(curl -fsS "${BASE_URL}/realms/mayabank")"
PUBLIC_KEY="$(REALM_JSON="${REALM_JSON}" python3 - <<'PY'
import os, textwrap, json
obj = json.loads(os.environ["REALM_JSON"])
raw = obj["public_key"].strip()
print("-----BEGIN PUBLIC KEY-----")
print("\n".join(textwrap.wrap(raw, 64)))
print("-----END PUBLIC KEY-----")
PY
)"

mkdir -p runtime/e2e/generated
PUBLIC_KEY="${PUBLIC_KEY}" RATE_LIMIT_PER_MINUTE="${RATE_LIMIT_PER_MINUTE}" KONG_CLIENT_IDS="${KONG_CLIENT_IDS}" python3 - <<'PY'
from pathlib import Path
import os
import re

template = Path("runtime/e2e/kong/kong.template.yml").read_text(encoding="utf-8")
key_lines = "\n".join("          " + line for line in os.environ["PUBLIC_KEY"].splitlines())

clients = os.environ["KONG_CLIENT_IDS"].split()
if not clients:
    raise SystemExit("KONG_CLIENT_IDS is empty")
consumers = []
for client in clients:
    if not re.fullmatch(r"[A-Za-z0-9._-]+", client):
        raise SystemExit(f"invalid client id: {client!r}")
    consumers.append(
        f"""  - username: {client}
    custom_id: {client}
    jwt_secrets:
      - key: "{client}"
        algorithm: RS256
        secret: "unused-for-rs256"
        rsa_public_key: |-
{key_lines}"""
    )

rendered = (
    template.replace("__KONG_CONSUMERS__", "\n".join(consumers))
    .replace("__RATE_LIMIT_PER_MINUTE__", os.environ["RATE_LIMIT_PER_MINUTE"])
)
Path("runtime/e2e/generated/kong.yml").write_text(rendered, encoding="utf-8")
print(f"KONG_DECLARATIVE_CONFIG_RENDER=PASS consumers={len(clients)}")
PY
