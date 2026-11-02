# LLD — MayaBank API Management Reference Implementation

**Classification:** REFERENCE_DESIGN / IMPLEMENTATION_CONTRACT  
**Runtime status:** standalone CI = CI_RUNTIME_PROVEN_E2E; shared-platform CRC profile = CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER (2026-10-02, replay pending after 2026-11-02 changes)

## 1. Scope

This LLD refines the HLD into deployable responsibilities for the MayaBank API Management lab. It is intentionally product-neutral at architecture level and uses Kong + Keycloak as the local reference implementation.

## 2. Runtime decomposition

```text
namespace: mayabank-edge
  api-gateway

namespace: mayabank-identity
  keycloak/reference external IdP

namespace: mayabank-api
  payment-api
  payment state/idempotency store

namespace: mayabank-events
  kafka/reference event platform

namespace: mayabank-observability
  metrics/logs/traces integration
```

A shared enterprise platform may host these services differently; namespace names are a lab contract, not a client prescription.

## 3. API contract

Primary contract: `apis/openapi/payment-api.yaml`

Operations:
- `POST /payments` — scope `payments.write`, mandatory `Idempotency-Key`;
- `GET /payments/{paymentId}` — scope `payments.read`.

Error media type: `application/problem+json`.

## 4. Event contract

Primary contract: `apis/asyncapi/payment-events.yaml`

Channel:
- `mayabank.payment.events.v1`

Message:
- `PaymentStatusChanged`

Minimum fields: `eventId`, `paymentId`, `status`, `occurredAt`.

## 5. Request processing sequence

1. Consumer resolves the public API endpoint.
2. Edge/WAF applies perimeter controls.
3. Gateway validates transport and schema/policy prerequisites.
4. Gateway identifies the client application (`azp` → Kong consumer), rejects clients that are not onboarded, and validates signature and expiry. With Kong OSS the gateway does **not** validate audience or scope (see §7).
5. Gateway applies per-consumer rate limits and forwards a controlled identity/security context.
6. Payment API validates issuer, audience and scope, then performs business/object authorization (a payment is only visible to the client that created it).
7. For create, API validates the payload against the contract and checks idempotency, scoped per client and bound to a payload fingerprint.
8. Payment dependency is invoked.
9. State change is emitted to the event platform.
10. Correlation/tracing data is propagated across the chain.

See `diagrams/uml/sequence-payment-create.puml`.

## 6. Gateway policy baseline

Conceptual order:

```text
correlation -> request limits -> schema/threat validation
-> authentication -> coarse authorization
-> quota/rate limit -> routing -> response filtering -> telemetry
```

Product-specific policy syntax is deferred to the corresponding lab.

## 7. Identity contract

Expected JWT checks:
- trusted issuer;
- expected signature algorithm/key;
- audience accepted by Payment API;
- expiration/not-before with bounded clock skew;
- required scope;
- no business authorization derived solely from possession of a valid token.

The backend must enforce ownership/object/function rules.

Placement of the checks in the reference implementation (`runtime/e2e/`):

| Check | Gateway (Kong OSS 3.9 `jwt`) | Payment API |
|---|---|---|
| client application onboarded | yes — one consumer per `azp` | — |
| signature (RS256) | yes | yes |
| expiry | yes | yes |
| issuer | indirect (realm key) | yes |
| audience | **no** (not supported by the OSS plugin) | yes |
| scope | no | yes |
| object ownership (BOLA) | no | yes |
| idempotency (client + payload) | no | yes |
| payload schema / IBAN checksum | no | yes |
| rate limit | yes — per consumer | — |
| payload size | yes — 1 MiB | — |

Moving audience/scope enforcement to the gateway requires an OIDC-capable policy (enterprise plugin or another product). It is a product decision, not assumed here.

Known limitation: the realm public key is copied into the Kong configuration at render time. A Keycloak key rotation requires re-rendering the configuration; JWKS-based validation at the gateway is not implemented.

## 8. Network and trust

Allowed conceptual flows:

```text
edge -> gateway
gateway -> IAM discovery/JWKS
gateway -> payment-api
payment-api -> payment dependency
payment-api -> event platform
payment-api -> datastore
runtime -> observability
```

Default-deny network policy is preferred where the platform permits it.

## 9. Secrets

No secret value is versioned. Runtime delivery must use environment injection, platform Secret references or an approved external secret manager. Examples in Git must contain placeholders only.

## 10. Health and probes

Payment API:
- readiness: service is ready to receive traffic;
- liveness: process remains healthy;
- dependency health must not automatically make liveness fail.

Gateway/IAM/event platform have separate health contracts.

## 11. Resource and capacity assumptions

No production sizing is claimed. Capture:
- average/peak TPS;
- payload sizes;
- TLS/JWT/policy cost;
- backend latency;
- event throughput;
- telemetry volume;
- HA headroom.

Benchmark with the real policy set before production sizing.

## 12. Failure behavior

| Failure | Expected architecture behavior |
|---|---|
| invalid/expired token | 401 |
| valid identity, insufficient permission | 403 |
| duplicate create with same idempotency key | deterministic replay/no duplicate payment |
| backend timeout | bounded timeout; no infinite retry |
| event platform unavailable | explicit failure/degradation strategy; no silent event loss |
| gateway saturation | quota/load shedding/capacity alerting |
| IAM unavailable | existing locally validated tokens may continue according to design; new authentication may fail |

These behaviors are design targets until observed in runtime evidence.

## 13. OpenShift deployment contract

Current reference manifest: `manifests/openshift/payment-api.yaml`.

Before promotion to a runtime claim, add/validate:
- immutable real image reference;
- securityContext/SCC compatibility;
- resource requests/limits;
- HPA/PDB where justified;
- NetworkPolicy;
- route/ingress and TLS;
- Secret delivery;
- ServiceMonitor/OTel integration;
- rollback procedure.

## 14. Evidence boundary

Design files, manifests and contracts are not runtime proof. Runtime promotion requires command/test output stored under `evidence/` and referenced from the claim/evidence matrix.


## 15. Shared-platform consumption profile

ADR-011 introduces a second, non-disruptive runtime profile under `runtime/shared-platform/`.

Target CRC namespaces:

```text
shared-observability
  -> otel-collector

keycloak-system
  -> RHBK/Keycloak specialist runtime
  -> shared realm mayabank

mayabank-api
  -> api-gateway / Kong 3.9.3
  -> payment-api fixture
```

Runtime contract:
- issuer: `https://keycloak.apps-crc.testing/realms/mayabank`;
- in-cluster JWKS: `http://keycloak-service.keycloak-system.svc:8080/realms/mayabank/protocol/openid-connect/certs`;
- OTLP traces: `http://otel-collector.shared-observability.svc:4318/v1/traces`;
- client/scopes/audience remain API-owned;
- Keycloak runtime lifecycle remains specialist-owned;
- OTel collector lifecycle remains shared-platform-owned.

This profile was observed successfully on OpenShift Local / CRC 4.22.7 on 2026-10-02 (`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`, see `evidence/crc/`). That observation predates the Payment API hardening of 2026-11-02 (payload validation, BOLA, per-client idempotency): the CRC profile must be replayed before those controls can be claimed on CRC. The CRC Kong configuration still uses a single issuer-keyed consumer; per-client consumers are implemented in `runtime/e2e/` and `runtime/kind/` only. The hardened CRC manifest binds the Admin API to pod-local loopback, removes port 8001 from the Service and uses status 8100 for probes. Those changes are static-only until CRC is retested.
