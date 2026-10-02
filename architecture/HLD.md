# HLD — MayaBank API Management Reference Architecture

**Classification:** REFERENCE_DESIGN  
**Runtime status:** NOT_RUNTIME_PROVEN

## 1. Purpose

Provide the high-level architecture for a banking API platform able to expose payment capabilities to digital channels and partners while keeping identity, API management, business authorization, event distribution and runtime responsibilities separated.

## 2. Architecture drivers

- secure API exposure for web, mobile and partner consumers;
- contract-first API design;
- explicit separation between API Management, IAM and business authorization;
- synchronous commands/queries combined with asynchronous domain events;
- hybrid/on-prem/cloud portability;
- resilience, observability and controlled lifecycle;
- traceability from requirements to ADRs and lower-level design.

## 3. Context

```text
Customer / Mobile / Web / Partner
              |
          WAF / Edge
              |
        API Management
              |
      OAuth/OIDC validation
              |
          Payment API
       /       |        \
 Payment Hub  Kafka   PostgreSQL
                 |
      Fraud / Notification / Reconciliation
```

## 4. Logical components

| Component | Responsibility |
|---|---|
| Edge/WAF | perimeter protection, TLS entry point, DDoS/WAF controls |
| API Management | API exposure, routing, policy enforcement, quotas, rate limits, telemetry |
| IAM / Authorization Server | authentication, client identity, token issuance, OIDC/OAuth2 |
| Payment API | domain façade, business validation, fine-grained authorization, idempotency |
| Payment Hub | core payment processing dependency |
| Event Streaming | publish payment lifecycle events |
| Data Store | payment/idempotency state required by the reference service |
| Observability | logs, metrics, traces, correlation and SLO evidence |

## 5. Trust boundaries

1. Internet/partner to edge.
2. Edge to API gateway.
3. API gateway to application namespace.
4. Application to IAM, event platform, database and payment systems.
5. Administrative/control-plane access separated from traffic data plane.

Authentication at the gateway does not replace object- or business-level authorization in the backend.

## 6. Integration principles

- REST/OpenAPI for synchronous commands and queries.
- AsyncAPI/events for state propagation and fan-out.
- Queue/event patterns for temporal decoupling.
- ESB/iPaaS or mediation only where transformation/orchestration requirements justify them.
- Legacy MQ/file/batch remain explicit integration options rather than being hidden behind an "API-first" slogan.

## 7. Security architecture

- OAuth 2.0 / OIDC with RFC 9700 security baseline.
- Authorization Code + PKCE for user-facing clients.
- Client Credentials for suitable machine-to-machine use cases.
- mTLS/DPoP/FAPI 2.0 evaluated according to exposure and risk.
- least-privilege scopes and audiences.
- backend object/function/business authorization.
- secrets externalized from Git.
- OWASP API Security Top 10 used as an architecture review baseline.

See `security/OWASP-API-Security-Top10-2023.md`.

## 8. Availability and resilience

- redundant application replicas where the runtime supports it;
- explicit timeouts;
- bounded retries with backoff/jitter;
- circuit breaker/bulkhead patterns when justified;
- idempotency for payment commands;
- load shedding/rate limiting at the appropriate layer;
- no HA claim until failure behavior is observed.

## 9. Observability

Required correlation path:

```text
consumer -> edge -> gateway -> API -> dependency
             <---- trace/correlation ---->
```

Baseline signals: traffic, latency, errors, saturation, auth failures, rate-limit hits, dependency timeouts and business outcome where appropriate.

## 10. Deployment view

Target reference runtime is Kubernetes/OpenShift. The architecture remains product-neutral; Kong is the preferred local lab gateway, while enterprise decisions may map to Apigee, Kong, MuleSoft Anypoint, Axway Amplify or another validated product.

## 11. Governance

- API inventory and ownership;
- design review before publication;
- OpenAPI/AsyncAPI contracts;
- lifecycle/deprecation policy;
- ADRs for material trade-offs;
- HLD to LLD traceability;
- evidence separated from design claims.

## 12. HLD-to-LLD handoff

This HLD defines responsibilities and boundaries. Concrete routes, namespaces, policies, probes, headers, ports, resource assumptions and failure handling are defined in `architecture/LLD.md`.
