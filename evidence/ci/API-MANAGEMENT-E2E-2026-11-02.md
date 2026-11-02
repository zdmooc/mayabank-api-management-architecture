# API Management E2E Runtime Evidence — 2026-11-02 (P0 hardening)

**Status:** CI_RUNTIME_PROVEN_E2E  
**Workflow:** `api-management-runtime-e2e`  
**GitHub Actions run:** `41436063790` — SUCCESS  
**Commit:** `537887c41e118927f6767aec42fc721b302d0ee4` (branch `feat/api-hardening-and-landing`, PR #5)  
**Versions:** Keycloak 26.8.0, Kong 3.9.3 (DB-less, OSS), Python 3.12 Payment API fixture

Run URL:
https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/41436063790

## Scope

Same bounded chain as the [2026-10-02 evidence](API-MANAGEMENT-E2E-2026-10-02.md), plus:

- one Kong consumer per onboarded client application (`key_claim_name: azp`);
- per-consumer rate limiting;
- Payment API object-level authorization, idempotency per client bound to the payload, and contract-aligned payload validation.

Before the runtime chain, the same workflow ran the Payment API unit and contract tests (28 tests, response bodies validated against `apis/openapi/payment-api.yaml`).

## Observed proof markers

```text
KEYCLOAK_E2E_BOOTSTRAP=PASS
KONG_DECLARATIVE_CONFIG_RENDER=PASS consumers=3
KONG_ADMIN_READY=PASS
KONG_JWT_MISSING_REJECTED=PASS
KEYCLOAK_CLIENT_CREDENTIALS_SCOPE_AUDIENCE=PASS
KONG_UNREGISTERED_CLIENT_REJECTED=PASS
KONG_KEYCLOAK_PAYMENT_CREATE=PASS
KONG_CORRELATION_ID=PASS
PAYMENT_IDEMPOTENCY_REPLAY=PASS
PAYMENT_IDEMPOTENCY_KEY_REUSE_REJECTED=PASS
PAYMENT_IBAN_CHECKSUM_REJECTED=PASS
PAYMENT_READ_SCOPE=PASS
PAYMENT_INSUFFICIENT_SCOPE_REJECTED=PASS
PAYMENT_BOLA_OTHER_CLIENT_REJECTED=PASS
PAYMENT_WRONG_AUDIENCE_REJECTED=PASS
KONG_REQUEST_SIZE_LIMIT=PASS
KONG_RATE_LIMIT_429=PASS
KONG_RATE_LIMIT_PER_CONSUMER_ISOLATION=PASS
KONG_INVALID_SIGNATURE_REJECTED=PASS
API_MANAGEMENT_E2E_RUNTIME=PASS
```

## New behaviors observed

| Behavior | Observed result |
|---|---|
| Valid Keycloak token (right audience and scopes) from a client not onboarded at the gateway | HTTP 401 at Kong |
| Read-only client reads a payment created by `payment-client` | HTTP 404 (no existence disclosure) |
| Same `Idempotency-Key`, different amount | HTTP 422 `idempotency_key_reused`, no new payment |
| IBAN with invalid mod-97 checksum | HTTP 422 `invalid_creditor_iban` |
| `payment-client` throttled (429), then `read-only-client` calls | not throttled (HTTP 404 from the API, i.e. request reached the backend) |

## Run history

Run `41435781573` (commit `2444a37`) failed on `KONG_INVALID_SIGNATURE_REJECTED`: the test altered the last base64url character of the signature, which can change only padding bits and leave the signature valid (the request then hit the rate limit, 429). The test was fixed to alter the first signature character. That failed run is not cited as evidence.

## Not proven by this run

- the shared-platform CRC profile with this Payment API version (replay pending);
- gateway-side audience/scope validation (not supported by Kong OSS `jwt`);
- JWKS key rotation at the gateway;
- mTLS/DPoP/FAPI, Kafka, HA, performance, production readiness.
