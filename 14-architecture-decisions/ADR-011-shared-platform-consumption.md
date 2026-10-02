# ADR-011 — Consume Shared Platform Services from API Management

**Status:** ACCEPTED  
**Date:** 2026-10-02

## Context

The API Management repository already owns a bounded standalone CI fixture:

```text
Keycloak 26.8.0 -> Kong 3.9.3 -> Payment API
```

That fixture is useful for reproducibility, but it must not become a second copy of the enterprise shared platform.

The MayaBank platform layering assigns common identity, observability, secrets, GitOps and quality contracts to `shared-platform-services-openshift`.

## Decision

API Management is a **SPECIALIZED_PLATFORM**.

It owns:
- Kong/API gateway runtime;
- gateway routes/plugins/policies;
- API lifecycle and governance;
- OpenAPI/AsyncAPI governance;
- API-specific SLOs and runtime verification.

It consumes:
- OIDC/identity: `CONSUME_SHARED`;
- OpenTelemetry/observability: `CONSUME_SHARED`;
- secrets integration: `CONSUME_SHARED`;
- GitOps conventions: `CONSUME_SHARED`;
- quality gates: `CONSUME_SHARED`.

The existing standalone Keycloak remains `DEDICATED_FOR_TEST`.

Kafka and PostgreSQL are not added to the gateway platform merely to complete a diagram. They remain external/product dependencies or dedicated test components when their own behavior is under test.

## CRC reference implementation

`runtime/shared-platform/` implements the target consumption profile:

```text
RHBK/Keycloak specialist runtime
  -> shared realm mayabank
       -> Kong/API Management
            -> Payment API fixture

Kong
  -> shared OTel Collector
```

Kong 3.9 uses the OpenTelemetry plugin for traces. Metrics via that plugin are not claimed for this version; shared OTel trace consumption is the target proof.

## Consequences

Positive:
- no duplicated platform ownership;
- standalone CI remains reproducible;
- CRC runtime can prove actual shared-service consumption;
- product APIs can onboard through a repeatable contract.

Trade-offs:
- CRC execution requires the shared Keycloak runtime to be Ready first;
- the lab uses a single-node CRC and is not HA;
- the Payment API remains a fixture with in-memory idempotency.

## Evidence status — 2026-10-02

The shared-platform profile has now been executed successfully on OpenShift Local / CRC 4.22.7.

Observed proof markers:

```text
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

Allowed claim:

`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`

The proof is bounded to the single-node CRC lab. It does not prove HA, multi-node scheduling, production sizing, production traffic, Kafka runtime, mTLS/FAPI end-to-end or production readiness.
