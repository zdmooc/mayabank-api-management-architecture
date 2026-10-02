# Threat Model API

Ce threat model est une vue synthétique. La couverture structurée des risques API est maintenue dans [OWASP API Security Top 10 — Architecture Mapping](../security/OWASP-API-Security-Top10-2023.md).

| Menace | Exemples de contrôles |
|---|---|
| Token theft | TLS, short-lived tokens, sender constraint |
| Credential stuffing | IdP protections, MFA, rate limits |
| API scraping / abuse | quotas, anomaly detection, business-flow controls |
| Injection | validation + backend safe coding |
| BOLA/IDOR | object-level authorization in backend |
| Function/property authorization failure | scopes/roles + backend authorization + response minimization |
| Replay / duplicate payment | idempotency, sender constraints where justified |
| DoS / resource exhaustion | edge protection, quotas, rate limits, payload/time/concurrency limits |
| SSRF | outbound allow-listing, egress controls, URL validation |
| Data leakage | minimisation, masking, controlled logs and responses |
| Unsafe downstream API | TLS/trust, schema validation, bounded timeout/retry |
| Supply chain | SBOM, signatures, CI controls |

## Trust rule

A successful authentication at the gateway never proves that the caller is allowed to access a specific payment object or execute a sensitive business action. Fine-grained authorization remains an application/domain responsibility.
