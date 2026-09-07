# 05 — API Gateway Architecture

## Responsabilités typiques

- TLS termination ou passthrough selon architecture ;
- authentication token validation ;
- routing ;
- rate limiting ;
- quotas ;
- transformations limitées ;
- headers ;
- logging/metrics ;
- canary/traffic management selon produit.

## Anti-pattern

Mettre toute la logique métier dans les policies du gateway.
