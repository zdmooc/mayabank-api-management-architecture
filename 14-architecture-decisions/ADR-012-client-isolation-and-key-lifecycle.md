# ADR-012 — OAuth client isolation, Kong Admin API and JWT key lifecycle

**Status:** Accepted for the bounded lab only; key rotation/CRC runtime remain unproven.
**Scope:** Kong 3.9.3 OSS / Keycloak 26.8.0 / ephemeral Payment API demo.

## Decision drivers
- A valid scope must never authorize one client to read another client's payment.
- An idempotency replay must be scoped to the authenticated client and operation.
- A policy or rate-limit for one CI partner must not consume another partner's allowance.
- Kong Admin API must not be published via the in-cluster API Gateway Service.
- Key rotation must be considered without falsely claiming zero-downtime resilience.

## Options and decisions

| Concern | Options evaluated | Decision for bounded lab | Production gap |
|---|---|---|---|
| Payment ownership | Gateway scope only; application `azp`; tenant/user ACL | Enforce signed JWT `azp` ownership at resource server, return 404 for cross-client reads | Model tenant and delegated users explicitly (JWT `sub` plus tenant claim) |
| Idempotency | Global key; client+operation+key; distributed DB | Client+key for the POST /payments operation, SHA-256 of canonical payload, 422 on mismatch, process lock | Persist transactionally with unique constraint, TTL and concurrency protection |
| Kong client identity | Single `iss` consumer; signed `azp` per consumer; enterprise OIDC plugin | Known E2E clients map to `azp` JWT consumers; local per-consumer rate limiting | Multi-pod distributed quotas; client onboarding and token compatibility |
| Admin API | Service 8001; localhost-only; external ACL | CRC Admin API binds to pod loopback; status port 8100 used for probes; no Admin Service endpoint | Access audit, RBAC, NetworkPolicy and CRC runtime retest |
| Signing key rotation | Static RSA key; rerender/redeploy; dynamic JWKS/OIDC | Static RS256 realm key is still rendered from Keycloak at startup | Rotation currently not automatically reconciled; overlap of old/new keys NOT PROVEN |

## Kong OSS key rotation constraint

The current Kong JWT plugin selects the RSA verification key from a declarative
JWT credential keyed by the signed `azp` claim. Kong OSS does not gain a
dynamic JWKS refresh mechanism from this configuration. Rotating a Keycloak
realm signing key can reject otherwise valid tokens until Kong configuration
is reconciled. A simple rerender/restart may also interrupt tokens signed by
the retiring key. Do not label this key lifecycle production-ready.

Before production migration: evaluate Kong Enterprise OIDC/JWKS management or
an explicitly tested safe reconciliation design, including overlapping keys,
rollback, alerting, client onboarding, token lifetime, and availability.

## Evidence requirements

- CI: two independently authenticated writer clients can reuse identical
  idempotency keys without sharing payment IDs.
- CI: both cross-client GET directions return 404.
- CI: changed payload with identical client/key returns 422.
- CI: one client's exhausted rate limit does not yield 429 for another.
- Static: CRC manifest has `KONG_ADMIN_LISTEN=127.0.0.1:8001`,
  `KONG_STATUS_LISTEN=0.0.0.0:8100`, and no Admin Service endpoint.
- CRC runtime: rerun the actual deployment and D090 Admin port-forward
  after applying the manifest. No such post-change runtime evidence exists yet.
- Key rotation E2E: pending, not claimed.

## API Management boundary

The lab demonstrates an API Gateway, an IdP and a payment resource server.
It does not implement developer portal, API product catalog, subscription
plans, organization onboarding, full gateway control-plane governance, or
distributed idempotency, and it does not demonstrate HA/DR/production readiness.
