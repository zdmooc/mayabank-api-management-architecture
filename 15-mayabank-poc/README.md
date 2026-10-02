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

sur OpenShift Local en consommant la plateforme commune lorsque le gate runtime CRC sera exécuté.

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


## Profil Shared Platform

Le profil `runtime/shared-platform/` remplace la duplication cible Keycloak/observabilité par des contrats `CONSUME_SHARED` : Shared OIDC + Shared OTel, tandis que Kong reste `SPECIALIZED_PLATFORM`. Le runtime Docker E2E reste disponible comme `DEDICATED_FOR_TEST`.
