# 10 — Event Driven APIs / Kafka

REST et événementiel sont complémentaires.

```text
Client
 ↓ HTTP
Payment API
 ↓
Payment Hub
 ↓
Kafka: payment.events
 ↓
Fraud / Notification / Reconciliation
```

## À maîtriser

- event vs command ;
- schema contract ;
- ownership ;
- partition key ;
- ordering ;
- idempotent consumer ;
- retry/DLQ ;
- schema compatibility ;
- observability ;
- PII dans événements.
