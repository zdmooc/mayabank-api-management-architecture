# 15 — POC MayaBank final

## Objectif

Démontrer :

```text
Consumer
 ↓
Kong Gateway
 ↓
OAuth/OIDC
 ↓
Payment API
 ├─ PostgreSQL
 └─ Kafka Payment Events
 ↓
Observability
```

sur OpenShift Local lorsque les labs seront exécutés.

## Livrables

- OpenAPI ;
- AsyncAPI ;
- architecture ;
- threat model ;
- policies ;
- ADR ;
- manifests ;
- tests ;
- SLO ;
- runbook ;
- RACI ;
- preuves d'exécution.
