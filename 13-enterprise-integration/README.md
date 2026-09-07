# 13 — Enterprise Integration

## Patterns

```text
Channels
  ↓
API Management
  ↓
Domain APIs
  ├─ Core Banking
  ├─ Payment Hub
  ├─ Pega/BPM
  ├─ ServiceNow
  ├─ Legacy MQ
  └─ Kafka
```

## L'architecte choisit entre

- synchronous API ;
- async event ;
- queue ;
- file/batch ;
- CDC ;
- orchestration ;
- choreography.

Le choix dépend du besoin métier, du couplage, de la latence et de la résilience.
