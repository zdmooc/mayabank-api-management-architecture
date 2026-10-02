# API Management — Shared Platform CRC Runtime Evidence

**Date:** 2026-10-02  
**Environment:** OpenShift Local / CRC 4.22.7  
**Node:** `crc` — single-node lab  
**Claim:** `CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`

## Scope proven

Observed runtime chain:

```text
Shared RHBK / Keycloak
  realm: mayabank
        |
        v
Kong 3.9.3
        |
        v
Payment API
        |
        +---- OTLP traces ----> Shared OpenTelemetry Collector
```

The API Management repository owns Kong, the Payment API fixture and API-specific OAuth client/scopes.

The shared platform owns the shared OIDC contract and shared OpenTelemetry collector.  
The Keycloak runtime is operated by the specialist repository `keycloak-enterprise-roadmap-v7`.

## Observed prerequisite evidence

Shared Identity on CRC:

```text
SHARED_KEYCLOAK_REALM=PASS
SHARED_OIDC_DISCOVERY=PASS
```

Shared OTel was already runtime-proven on the same CRC.

## Observed API Management runtime evidence

Deployment state observed:

- `payment-api` Deployment: 1/1 Available;
- `api-gateway` Deployment: 1/1 Available;
- Kong pod: 1/1 Running, zero restarts after the final constrained profile;
- Kong declarative configuration loaded successfully;
- Kong readiness/liveness `/status` probes returned HTTP 200;
- OpenShift Route exposed the API gateway.

Observed proof markers:

```text
KONG_SHARED_CONFIG_RENDER=PASS
KONG_SHARED_PLATFORM_DEPLOY=PASS
API_SHARED_OIDC_TOKEN=PASS
API_SHARED_GATEWAY_PAYMENT=PASS
KONG_SHARED_OTEL_TRACE=PASS
API_MANAGEMENT_SHARED_PLATFORM_CRC=PASS
```

## Runtime behaviors proven

- client_credentials token obtained from the shared `mayabank` realm;
- issuer, audience and required scopes validated;
- unauthenticated gateway request rejected;
- authenticated payment creation succeeded through Kong;
- payment read succeeded through Kong;
- correlation header observed;
- Kong trace export observed in the shared OTel collector.

## CRC-specific constrained runtime adjustments

These settings are lab-only and are not production sizing recommendations:

- Payment API CPU request reduced to `10m`;
- Kong CPU request reduced to `25m`;
- Kong CPU limit remains `750m`;
- Kong memory limit remains `512Mi`;
- `KONG_NGINX_WORKER_PROCESSES=1` to avoid startup OOM on the constrained single-node CRC.

Observed issue/resolution sequence:

1. Keycloak initially could not schedule because CRC CPU requests were near saturation.
2. Keycloak CRC request was compacted and the pod recreated successfully.
3. Payment API initially suffered rollout contention from duplicate ReplicaSets on the constrained node.
4. CRC deployments were switched to `Recreate`.
5. Kong initially could not schedule because CPU headroom was exhausted.
6. Payment API and Kong CRC requests were compacted.
7. Kong then scheduled but was `OOMKilled` with 8 auto-detected OpenResty workers.
8. Kong was constrained to one worker and became stable: 1/1 Running, zero restarts.

## Allowed claim

`CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER`

This means the API Management profile has been observed consuming shared OIDC and shared OTel on CRC.

## Explicit non-claims

This evidence does **not** prove:

- multi-node or multi-AZ availability;
- production sizing or performance;
- HA / DR / PRA;
- durable payment persistence;
- Kafka runtime for this profile;
- mTLS/FAPI end-to-end;
- external IdP federation;
- production secret rotation;
- production readiness.
