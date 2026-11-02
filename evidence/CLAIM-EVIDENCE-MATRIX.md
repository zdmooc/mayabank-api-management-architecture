# Claim / Evidence Matrix

**Purpose:** separate architecture capability from observed runtime evidence.

| Capability | Current level | Evidence |
|---|---|---|
| API strategy / lifecycle / governance | REFERENCE_DESIGN | repository docs + review checklist |
| REST/OpenAPI contract | SPEC_LINTED | `apis/openapi/payment-api.yaml` (OpenAPI 3.2.0) linted by Redocly in validate-contracts CI |
| Contract conformance of API responses | UNIT_TESTED | `runtime/e2e/payment-api/tests/` validates every response body against the OpenAPI component schemas |
| AsyncAPI/event contract | SPEC_LINTED | `apis/asyncapi/payment-events.yaml` validated by the official AsyncAPI parser in validate-contracts CI |
| OAuth/OIDC/FAPI architecture | REFERENCE_DESIGN | `04-api-security/`, ADR-003, ADR-007 |
| OWASP API Security architecture mapping | REFERENCE_DESIGN | `security/OWASP-API-Security-Top10-2023.md` |
| HLD | REFERENCE_DESIGN | `architecture/HLD.md` |
| LLD | IMPLEMENTATION_CONTRACT | `architecture/LLD.md` |
| UML component/sequence/deployment | STATIC_VALIDATED | `diagrams/uml/` + architecture deliverables CI gate |
| OpenShift Payment API manifest | STATIC_ASSET | `manifests/openshift/payment-api.yaml` |
| Shared-platform CRC profile | CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER | observed OpenShift Local / CRC 4.22.7 execution on 2026-10-02; **replay pending** for the Payment API changes of 2026-11-02 |
| Shared OIDC consumption on CRC | CRC_RUNTIME_PROVEN | `API_SHARED_OIDC_TOKEN=PASS` |
| Kong → shared OTel traces on CRC | CRC_RUNTIME_PROVEN | `KONG_SHARED_OTEL_TRACE=PASS` |
| Kong gateway runtime | CI_RUNTIME_PROVEN_E2E | run `36996509086` |
| Keycloak integration in standalone CI | CI_RUNTIME_PROVEN_E2E | Keycloak 26.8.0, run `36996509086` |
| OAuth2 client_credentials | CI_RUNTIME_PROVEN_E2E | audience + scopes observed, run `36996509086` |
| JWT negative controls | CI_RUNTIME_PROVEN_E2E | missing token + invalid signature rejected |
| Insufficient scope behavior | CI_RUNTIME_PROVEN_E2E | HTTP 403 observed |
| Wrong audience behavior | CI_RUNTIME_PROVEN_E2E | HTTP 401 observed |
| Request-size limiting | CI_RUNTIME_PROVEN_E2E | HTTP 413 observed |
| Rate limiting | CI_RUNTIME_PROVEN_E2E | HTTP 429 observed with reduced CI-only threshold |
| Payment API via gateway | CI_RUNTIME_PROVEN_E2E | create/read through Kong |
| Idempotency | CI_RUNTIME_PROVEN_E2E | deterministic replay observed |
| Idempotency key reuse with different payload | CI_RUNTIME_PROVEN_E2E | HTTP 422 `idempotency_key_reused` (`PAYMENT_IDEMPOTENCY_KEY_REUSE_REJECTED`) |
| Idempotency scoped per client application | UNIT_TESTED | same key from two clients → two payments |
| Object-level authorization (OWASP API1 / BOLA) | CI_RUNTIME_PROVEN_E2E | other client with valid read scope → HTTP 404 (`PAYMENT_BOLA_OTHER_CLIENT_REJECTED`) |
| Payload validation (schema + IBAN mod-97) | CI_RUNTIME_PROVEN_E2E | HTTP 422 on invalid checksum (`PAYMENT_IBAN_CHECKSUM_REJECTED`); field-level cases unit-tested |
| Gateway client allow-list (one Kong consumer per `azp`) | CI_RUNTIME_PROVEN_E2E | valid token of a non-onboarded client → HTTP 401 (`KONG_UNREGISTERED_CLIENT_REJECTED`) |
| Per-consumer rate limiting | CI_RUNTIME_PROVEN_E2E | throttled client does not throttle another (`KONG_RATE_LIMIT_PER_CONSUMER_ISOLATION`) |
| Audience/scope validation at the gateway | NOT_IMPLEMENTED | Kong OSS `jwt` plugin does not support it; enforced by the resource server (LLD §7) |
| Correlation ID | CI_RUNTIME_PROVEN_E2E | gateway response header observed |
| Expired-token behavioral test | NOT_PROVEN | dedicated expiry case not yet executed |
| Kafka runtime in this repo | NOT_PROVEN | LAB-09 pending |
| OpenShift runtime | CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER | shared-platform profile executed successfully on CRC 4.22.7 |
| Full target architecture E2E | NOT_PROVEN | Kafka/OpenShift/HA not included in current CI proof |
| Production readiness | NOT_CLAIMED | — |

## Primary runtime evidence

- `evidence/ci/API-MANAGEMENT-E2E-2026-11-02.md` — run `41436063790`, SUCCESS (P0 hardening: BOLA, idempotency reuse, IBAN, per-client consumers)

- `evidence/ci/API-MANAGEMENT-E2E-2026-10-02.md`
- GitHub Actions run `36996509086` — SUCCESS
- commit `7b9f7d7feb7297c1e50ad99992e4d03045173e86`

## Known gaps (not claimed)

Tracked in [00-roadmap/evolution-2026-2027.md](../00-roadmap/evolution-2026-2027.md#dette-technique-connue-hors-profils): Kong admin port reachable inside the CRC namespace, static realm key in the Kong configuration (no JWKS rotation), `curl -k` in CRC scripts, text-match OTel assertion, gateway errors not in `application/problem+json`, in-memory state.

## Portfolio linkage

Deep Keycloak/IAM runtime evidence also exists in `zdmooc/keycloak-enterprise-roadmap-v7`. The successful standalone E2E run above is owned by this repository and is valid evidence for the bounded Kong + Keycloak + Payment API integration.

## Promotion rule

A capability moves to a runtime-proven level only when:
1. the exact version/environment is recorded;
2. nominal and negative tests are executed;
3. sanitized evidence is stored;
4. the claim is updated here;
5. relevant ADRs are updated if execution changes the design.

Runtime proof is scoped: proving the bounded CI chain does not prove OpenShift, Kafka, HA or production readiness.

## Shared-platform target evidence gate

The target profile is implemented under `runtime/shared-platform/` and validated statically. It consumes:
- issuer `https://keycloak.apps-crc.testing/realms/mayabank`;
- in-cluster JWKS from `keycloak-service.keycloak-system.svc`;
- OTLP traces endpoint `otel-collector.shared-observability.svc:4318`.

Observed successful CRC run produced these markers:

```text
API_SHARED_KEYCLOAK_CLIENT=PASS
PAYMENT_API_BUILD=PASS
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```


## Shared-platform CRC runtime evidence — 2026-10-02

Primary evidence:
- `evidence/crc/API-MANAGEMENT-SHARED-PLATFORM-CRC-2026-10-02.md`

Observed terminal markers:

```text
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

Allowed claim:
`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`.

Scope remains bounded to single-node CRC/OpenShift Local; HA, multi-node, production sizing, Kafka integration and production readiness remain unproven.
