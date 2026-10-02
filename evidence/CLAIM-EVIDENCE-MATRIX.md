# Claim / Evidence Matrix

**Purpose:** separate architecture capability from observed runtime evidence.

| Capability | Current level | Evidence |
|---|---|---|
| API strategy / lifecycle / governance | REFERENCE_DESIGN | repository docs + review checklist |
| REST/OpenAPI contract | STATIC_VALIDATED | `apis/openapi/payment-api.yaml` + validate-contracts CI |
| AsyncAPI/event contract | STATIC_VALIDATED | `apis/asyncapi/payment-events.yaml` + validate-contracts CI |
| OAuth/OIDC/FAPI architecture | REFERENCE_DESIGN | `04-api-security/`, ADR-003, ADR-007 |
| OWASP API Security architecture mapping | REFERENCE_DESIGN | `security/OWASP-API-Security-Top10-2023.md` |
| HLD | REFERENCE_DESIGN | `architecture/HLD.md` |
| LLD | IMPLEMENTATION_CONTRACT | `architecture/LLD.md` |
| UML component/sequence/deployment | STATIC_VALIDATED | `diagrams/uml/` + architecture deliverables CI gate |
| OpenShift Payment API manifest | STATIC_ASSET | `manifests/openshift/payment-api.yaml` |\n| Shared-platform CRC profile | STATIC_VALIDATED | `runtime/shared-platform/` + validate-contracts CI |\n| Shared OIDC consumption on CRC | NOT_PROVEN | runtime execution pending |\n| Kong → shared OTel traces on CRC | NOT_PROVEN | runtime execution pending |
| Kong gateway runtime | CI_RUNTIME_PROVEN_E2E | run `36984578912` |
| Keycloak integration in this repo | CI_RUNTIME_PROVEN_E2E | Keycloak 26.8.0, run `36984578912` |
| OAuth2 client_credentials | CI_RUNTIME_PROVEN_E2E | audience + scopes observed, run `36984578912` |
| JWT negative controls | CI_RUNTIME_PROVEN_E2E | missing token + invalid signature rejected |
| Payment API via gateway | CI_RUNTIME_PROVEN_E2E | create/read through Kong |
| Idempotency | CI_RUNTIME_PROVEN_E2E | deterministic replay observed |
| Correlation ID | CI_RUNTIME_PROVEN_E2E | gateway response header observed |
| Kafka runtime in this repo | NOT_PROVEN | LAB-09 pending |
| OpenShift runtime | NOT_PROVEN | shared-platform CRC execution pending; LAB-07 remains manual |
| Full target architecture E2E | NOT_PROVEN | Kafka/OpenShift/HA not included in current CI proof |
| Production readiness | NOT_CLAIMED | — |

## Primary runtime evidence

- `evidence/ci/API-MANAGEMENT-E2E-2026-10-02.md`
- GitHub Actions run `36984578912` — SUCCESS
- commit `51424944ca46758b0e20896e6d4dd995727c44d5`

## Portfolio linkage

Deep Keycloak/IAM runtime evidence also exists in `zdmooc/keycloak-enterprise-roadmap-v7`. The successful E2E run above is owned by this repository and is therefore valid evidence for the bounded Kong + Keycloak + Payment API integration.

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

Promotion requires an observed successful CRC run with these markers:

```text
API_SHARED_KEYCLOAK_CLIENT=PASS
PAYMENT_API_BUILD=PASS
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```
