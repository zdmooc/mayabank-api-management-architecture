# 09 — Résilience et performance

## Patterns

- timeout ;
- retry borné avec backoff/jitter ;
- circuit breaker ;
- bulkhead ;
- rate limiting ;
- queue/buffer lorsque asynchrone ;
- idempotence ;
- load shedding ;
- cache lorsque cohérent métier.

## Règle

Un retry automatique sur `POST /payments` sans idempotence peut créer un double paiement.
