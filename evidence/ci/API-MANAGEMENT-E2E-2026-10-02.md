# API Management E2E Runtime Evidence — 2026-10-02

**Status:** CI_RUNTIME_PROVEN_E2E  
**Workflow:** `api-management-runtime-e2e`  
**GitHub Actions run:** `36996509086`  
**Commit:** `7b9f7d7feb7297c1e50ad99992e4d03045173e86`  
**Conclusion:** SUCCESS

Run URL:
https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/36996509086

## Runtime scope

```text
OAuth2 client
   |
   | client_credentials
   v
Keycloak 26.8.0
   |
   | RS256 JWT
   v
Kong Gateway 3.9.3
   |
   | protected /payments
   v
Payment API
```

This evidence proves a deliberately bounded API Management chain. It is not OpenShift, Kafka, HA or production evidence.

## Observed proof markers

```text
KEYCLOAK_E2E_BOOTSTRAP=PASS
KONG_DECLARATIVE_CONFIG_RENDER=PASS
KONG_ADMIN_READY=PASS
KONG_JWT_MISSING_REJECTED=PASS
KEYCLOAK_CLIENT_CREDENTIALS_SCOPE_AUDIENCE=PASS
KONG_KEYCLOAK_PAYMENT_CREATE=PASS
KONG_CORRELATION_ID=PASS
PAYMENT_IDEMPOTENCY_REPLAY=PASS
PAYMENT_READ_SCOPE=PASS
PAYMENT_INSUFFICIENT_SCOPE_REJECTED=PASS
PAYMENT_WRONG_AUDIENCE_REJECTED=PASS
KONG_REQUEST_SIZE_LIMIT=PASS
KONG_RATE_LIMIT_429=PASS
KONG_INVALID_SIGNATURE_REJECTED=PASS
API_MANAGEMENT_E2E_RUNTIME=PASS
```

## Behaviors observed

- Keycloak realm/client/client-scope bootstrap completed.
- Runtime-only credentials were generated and masked in GitHub Actions.
- OAuth2 `client_credentials` token issuance succeeded.
- Token contained the expected Payment API audience and read/write scopes.
- Kong declarative configuration rendered and loaded.
- Gateway rejected a request with no JWT.
- Gateway accepted a valid Keycloak RS256 JWT.
- Payment creation succeeded through Kong.
- Correlation ID was returned by Kong.
- Repeating the same idempotency key returned the same payment identifier.
- Payment read succeeded with the required scope.
- A read-only client was rejected with HTTP 403 on the write operation.
- A validly signed token with the wrong audience was rejected with HTTP 401 by the resource server.
- A payload above the configured 1 MiB gateway limit was rejected with HTTP 413.
- The Kong rate-limit policy was behaviorally proven with HTTP 429 using a reduced CI-only threshold; the reference/default policy remains 120 requests/minute.
- A deterministically modified JWT signature was rejected.

## Security boundary

The runtime credentials are generated for each CI run and are not versioned. GitHub Actions masks them before they are written to `GITHUB_ENV`.

Earlier failed development runs used ephemeral credentials that were destroyed with their containers. Those failed runs are not cited as evidence.

## Not proven by this run

- OpenShift/CRC deployment;
- Kubernetes networking/security controls;
- Kafka/AsyncAPI runtime;
- mTLS/DPoP/FAPI runtime;
- HA/multi-site;
- performance/capacity;
- production readiness.

## Architecture conclusion

The repository now demonstrates both:
1. solution architecture artifacts: HLD, LLD, UML, OWASP mapping, ADRs and API contracts;
2. a narrow but real API Management runtime chain integrating Kong, Keycloak and a protected Payment API.

Production or platform-level claims remain explicitly out of scope.
