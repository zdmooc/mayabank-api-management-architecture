# Runtime E2E — Kong + Keycloak + Payment API

## Status

The workflow is designed to prove a narrow, reproducible API Management chain:

```text
client
  -> Keycloak 26.8.0 (client_credentials)
  -> Kong Gateway 3.9.3 (consumer per client `azp`, JWT signature/exp, policies)
  -> Payment API (issuer/audience/scope, BOLA, idempotency, payload validation)
```

This is a **CI lab**, not production evidence.

## What is tested

- Keycloak realm/client/client-scope bootstrap;
- OAuth2 `client_credentials`;
- access token with `payments.write`, `payments.read` and `payment-api` audience;
- Kong RS256 JWT signature and expiration validation;
- gateway correlation ID;
- gateway rate-limit and request-size policies loaded;
- Payment API issuer/audience/scope validation;
- protected payment creation;
- idempotent replay;
- protected payment read;
- missing-token rejection;
- insufficient-scope rejection (403);
- wrong-audience rejection (401);
- request-size rejection (413);
- rate-limit rejection (429, reduced CI-only threshold);
- invalid-signature rejection;
- non-onboarded client rejected by the gateway (401, valid token without Kong consumer);
- object-level authorization: another client cannot read a payment it does not own (404);
- idempotency key reused with a different payload (422);
- invalid IBAN checksum (422);
- per-consumer rate-limit isolation (a throttled client does not throttle another).

Before the runtime chain, the workflow runs the Payment API unit and contract tests (`payment-api/tests/`), which validate every response body against `apis/openapi/payment-api.yaml`.

## Security model

No fixed credential is committed. The GitHub Actions workflow generates:
- Keycloak bootstrap admin password;
- one secret per test client (`payment-client`, `read-only-client`, `wrong-audience-client`, `unregistered-client`).

Kong's RS256 credential uses the Keycloak realm **public** key generated at runtime. The placeholder `secret` required by Kong declarative JWT credentials is not used for RS256 verification.

## Product boundary

Kong OSS JWT resolves the consumer from `azp` (one consumer per onboarded client, see `KONG_CLIENT_IDS` in `scripts/render-kong-config.sh`) and validates signature and expiry. Audience and OAuth scope semantics are validated by the resource server in this lab. An enterprise OIDC plugin may move more OAuth/OIDC policy to the gateway, but that is a separate product/capability decision.

## Versions

- Keycloak: 26.8.0
- Kong Docker Official Image: 3.9.3
- Python: 3.12

## Local execution

```bash
export KC_BOOTSTRAP_ADMIN_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"
export PAYMENT_CLIENT_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
export READ_ONLY_CLIENT_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
export WRONG_AUDIENCE_CLIENT_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
export UNREGISTERED_CLIENT_SECRET="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
export RATE_LIMIT_PER_MINUTE=20

docker compose -f runtime/e2e/docker-compose.yml up -d --build keycloak payment-api
bash runtime/e2e/scripts/bootstrap-keycloak.sh
bash runtime/e2e/scripts/render-kong-config.sh
docker compose -f runtime/e2e/docker-compose.yml up -d kong
bash runtime/e2e/scripts/test-e2e.sh
docker compose -f runtime/e2e/docker-compose.yml down -v
```
