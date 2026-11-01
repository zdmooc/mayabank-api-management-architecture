# Payment API and Kong hardening — bounded CI evidence, 2026-11-01

**Branch:** `fix/payment-security-and-kong-hardening-20261101`
**Proven commit:** `44de4e4f1505bbcec05b810578afdf2f01f7eb1e`
**Status:** CI_RUNTIME_PROVEN_E2E for this PR branch only; not yet merged to main.
**Runtime:** GitHub-hosted Docker Compose, Kong 3.9.3, Keycloak 26.8.0, Flask Payment API.

## Executions

- [runtime E2E workflow #41351896282](https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/41351896282) — SUCCESS.
- [validation/contracts workflow #41351896301](https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/41351896301) — SUCCESS.
- Unit tests, JSON Schema contract shape, Spectral lint and AsyncAPI CLI validation are included in validation workflow.

## Observed runtime markers (from E2E job log)

```text
KEYCLOAK_E2E_BOOTSTRAP=PASS
KONG_DECLARATIVE_CONFIG_RENDER=PASS
KONG_ADMIN_READY=PASS
KEYCLOAK_CLIENT_CREDENTIALS_SCOPE_AUDIENCE=PASS
PAYMENT_IDEMPOTENCY_REPLAY=PASS
PAYMENT_IDEMPOTENCY_CONFLICT=PASS
PAYMENT_CROSS_CLIENT_IDEMPOTENCY_AND_BOLA=PASS
PAYMENT_CROSS_CLIENT_READ_DENIED=PASS
PAYMENT_INSUFFICIENT_SCOPE_REJECTED=PASS
PAYMENT_WRONG_AUDIENCE_REJECTED=PASS
KONG_REQUEST_SIZE_LIMIT=PASS
KONG_INVALID_SIGNATURE_REJECTED=PASS
KONG_RATE_LIMIT_429=PASS
KONG_PER_CLIENT_RATE_LIMIT_ISOLATED=PASS
API_MANAGEMENT_E2E_RUNTIME=PASS
```

## What the proof means

- Two independently authenticated clients with write permissions used the **same**
  idempotency key and got **different** payment IDs.
- Client A cannot read client B's payment, and vice versa (404).
- A changed payload reused with the same client/key is rejected with 409.
- The separate read-only client retains its own quota after A reaches HTTP 429.
- JWT invalid signature, wrong audience and insufficient scope are rejected.
- Kong Admin exposure is checked **statically** on the CRC manifest, not by a live CRC cluster.

## Explicit non-claims

- No new CRC or OpenShift execution was performed on the hardened branch.
- Kong key rotation / JWKS refresh and old/new signing key overlap are not proven.
- Payment persistence and idempotency are in-memory, single-process and NOT
  distributed or durable.
- Local Kong rate-limit policy is NOT a multi-node quota implementation.
- No dedicated CRC CA verification proof, trace-id-targeted OTel proof, HA,
  Kafka integration, production secret lifecycle, or production readiness.
- Manual labs remain unverified unless executed and recorded separately.
