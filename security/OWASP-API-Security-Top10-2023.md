# OWASP API Security Top 10 — Architecture Mapping

**Baseline:** OWASP API Security Top 10 — 2023  
**Purpose:** architecture review mapping, not a penetration-test claim.

| OWASP risk | MayaBank architecture controls |
|---|---|
| API1 Broken Object Level Authorization | Payment API checks ownership/authorization for every object identifier; gateway authentication is insufficient by itself |
| API2 Broken Authentication | OIDC/OAuth2 baseline, PKCE, strict redirect URIs, short-lived tokens, issuer/audience validation, strong client authentication where required |
| API3 Broken Object Property Level Authorization | request/response schema discipline, explicit writable/readable fields, backend property-level authorization, response minimization |
| API4 Unrestricted Resource Consumption | quotas, rate limits, payload limits, timeouts, concurrency/capacity controls, observability |
| API5 Broken Function Level Authorization | explicit scopes/roles plus backend function authorization; administrative operations isolated |
| API6 Unrestricted Access to Sensitive Business Flows | anti-automation/risk controls, transaction limits, idempotency, fraud controls and business monitoring |
| API7 Server Side Request Forgery | outbound destination allow-listing, egress controls, URL/input validation, no arbitrary backend fetch from consumer input |
| API8 Security Misconfiguration | hardened defaults, TLS, controlled CORS, no debug exposure, secure headers, configuration review and automated validation |
| API9 Improper Inventory Management | governed API inventory, ownership, version/lifecycle/deprecation, removal of shadow/obsolete endpoints |
| API10 Unsafe Consumption of APIs | validate downstream responses, bounded timeouts/retries, TLS/trust validation, schema validation and dependency risk review |

## Architecture review questions

- Is object-level authorization enforced in the Payment API?
- Are scope and audience definitions specific to each API?
- Are request and response fields minimized?
- Are payload, concurrency and rate limits explicit?
- Are sensitive payment flows protected against automation and replay?
- Can the service make arbitrary outbound requests based on user input?
- Are non-production/debug/admin surfaces isolated?
- Is every exposed API inventoried with an owner and lifecycle?
- Are downstream APIs treated as untrusted dependencies and validated?

## Evidence rule

A checked architecture control means the design requires the control. It does not mean the implementation has passed a security test. Runtime and security-test evidence must be recorded separately.

Official reference: https://owasp.org/API-Security/
