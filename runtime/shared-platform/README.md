# API Management — Shared Platform CRC profile

## Purpose

This profile proves the target ownership model without replacing the existing standalone CI fixture.

```text
OpenShift Local / CRC
  |
  +-- shared-observability
  |     +-- OTel Collector
  |
  +-- keycloak-system
  |     +-- RHBK / Keycloak runtime (specialist repository)
  |     +-- shared realm: mayabank
  |
  +-- mayabank-api
        +-- Kong 3.9.3
        +-- Payment API
```

## Ownership

Consumed from `shared-platform-services-openshift`:
- shared OIDC issuer/realm contract;
- shared OpenTelemetry collector;
- secret/GitOps/quality conventions.

Owned here:
- Kong runtime and gateway policy configuration;
- API-specific client/scopes/audience;
- Payment API fixture;
- API runtime verification.

Keycloak Operator/PostgreSQL/Keycloak CR remain owned by `keycloak-enterprise-roadmap-v7`.

## Prerequisites

1. CRC/OpenShift Local is Running and the active context is `crc-admin`.
2. Shared observability is already proven and `otel-collector` is 1/1 Ready.
3. RHBK/Keycloak specialist runtime is Ready in `keycloak-system`.
4. `shared-platform-services-openshift/scripts/bootstrap-shared-identity-crc.sh` has created/verified the `mayabank` realm.
5. `oc`, `curl`, `jq`, Python 3 and Bash are available.

## Execute

```bash
bash runtime/shared-platform/scripts/deploy-crc.sh
bash runtime/shared-platform/scripts/test-crc.sh
```

The deployment uses an OpenShift Binary BuildConfig for the Payment API, so no external placeholder application image is required.

## Expected proof markers

```text
API_SHARED_KEYCLOAK_CLIENT=PASS
PAYMENT_API_BUILD=PASS
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

## Truth boundary

Observed on 2026-10-02, this profile is `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER` on OpenShift Local / CRC 4.22.7.

It does not prove HA, production sizing, Kafka, durable payment persistence, mTLS/FAPI or production readiness.


## Observed CRC result

```text
KONG_SHARED_CONFIG_RENDER=PASS
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

Evidence: `evidence/crc/API-MANAGEMENT-SHARED-PLATFORM-CRC-2026-10-02.md`.

CRC-specific compact requests and the one-worker Kong setting are local-lab constraints only and must not be reused as production sizing.
