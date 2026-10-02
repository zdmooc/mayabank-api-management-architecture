# Shared Platform API Management Closure Record

**Date:** 2026-10-02  
**Status:** CLOSED  
**Evidence level:** `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`

## Final observed chain

```text
RHBK / Keycloak
  realm: mayabank
        |
        | OIDC / OAuth2 client_credentials
        v
Kong 3.9.3
        |
        | gateway routing + correlation + JWT enforcement
        v
Payment API
        |
        | OTLP traces
        v
Shared OpenTelemetry Collector
```

## Final markers

```text
SHARED_KEYCLOAK_REALM=PASS
SHARED_OIDC_DISCOVERY=PASS
KONG_SHARED_CONFIG_RENDER=PASS
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

## Runtime state observed

- OpenShift Local / CRC 4.22.7;
- Keycloak/RHBK Ready;
- shared OTel Collector Ready;
- Payment API 1/1 Available;
- Kong 1/1 Available and zero restarts after final tuning;
- Kong declarative configuration loaded;
- readiness/liveness `/status` returned HTTP 200.

## Lab-only constrained settings

These settings exist only to fit the single-node workstation lab:

- Payment API request: `10m CPU`;
- Kong request: `25m CPU`;
- Kong `KONG_NGINX_WORKER_PROCESSES=1`;
- Recreate deployment strategy to avoid duplicate ReplicaSet contention.

They are explicitly **not production sizing**.

## Problems resolved during execution

1. Shared Keycloak scheduling pressure on constrained CRC.
2. Windows Git Bash/Python temp-path portability.
3. Payment API duplicate rollout contention.
4. Kong scheduling pressure.
5. Kong startup OOM from auto-detected 8 OpenResty workers.
6. Script false negatives caused by unordered pod selection.
7. Final `oc get` resource-list syntax defect.

## Closure decision

The API Management shared-platform onboarding is complete for the intended CRC proof.

Future work is mission-driven only:
- HA/multi-node;
- production sizing/performance;
- mTLS/FAPI end-to-end;
- Kafka/event integration;
- production secrets/PKI;
- external IdP/federation.

No further CRC work is required for this capability unless one of those proof gaps becomes a mission requirement.
