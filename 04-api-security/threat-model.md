# Threat Model API

| Menace | Exemples de contrôles |
|---|---|
| Token theft | TLS, short-lived tokens, sender constraint |
| Credential stuffing | IdP protections, MFA, rate limits |
| API scraping | quotas, anomaly detection |
| Injection | validation + backend safe coding |
| BOLA/IDOR | authorization objet côté backend |
| Replay | nonce/idempotency/sender constraints selon cas |
| DoS | edge protection, quotas, rate limit |
| Data leakage | minimisation, masking, logs contrôlés |
| Supply chain | SBOM, signatures, CI controls |
