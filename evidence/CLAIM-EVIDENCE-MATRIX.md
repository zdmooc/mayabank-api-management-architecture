# Claim / Evidence Matrix

**Purpose:** separate architecture capability from observed runtime evidence.

| Capability | Current level | Evidence |
|---|---|---|
| API strategy / lifecycle / governance | REFERENCE_DESIGN | repository docs + review checklist |
| REST/OpenAPI contract | STATIC_ASSET | `apis/openapi/payment-api.yaml` |
| AsyncAPI/event contract | STATIC_ASSET | `apis/asyncapi/payment-events.yaml` |
| OAuth/OIDC/FAPI architecture | REFERENCE_DESIGN | `04-api-security/`, ADR-003, ADR-007 |
| OWASP API Security architecture mapping | REFERENCE_DESIGN | `security/OWASP-API-Security-Top10-2023.md` |
| HLD | REFERENCE_DESIGN | `architecture/HLD.md` |
| LLD | IMPLEMENTATION_CONTRACT | `architecture/LLD.md` |
| UML component/sequence/deployment | STATIC_ASSET | `diagrams/uml/` |
| OpenShift Payment API manifest | STATIC_ASSET | `manifests/openshift/payment-api.yaml` |
| Kong gateway runtime | NOT_PROVEN | LAB-03 pending |
| Keycloak integration in this repo | NOT_PROVEN | LAB-04 pending; specialist Keycloak repository has separate evidence |
| Kafka runtime in this repo | NOT_PROVEN | LAB-09 pending |
| OpenShift runtime | NOT_PROVEN | LAB-07 pending |
| End-to-end API Management POC | NOT_PROVEN | LAB-12 pending |
| Production readiness | NOT_CLAIMED | — |

## Portfolio linkage

Keycloak/IAM runtime evidence is owned by `zdmooc/keycloak-enterprise-roadmap-v7`. This repository consumes that capability conceptually but does not reuse another repository's evidence to claim an API Management end-to-end runtime.

## Promotion rule

A capability moves to a runtime-proven level only when:
1. the exact version/environment is recorded;
2. nominal and negative tests are executed;
3. sanitized evidence is stored;
4. the claim is updated here;
5. relevant ADRs are updated if execution changes the design.
