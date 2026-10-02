# Labs — statut et preuves

Les 12 labs manuels restent suivis individuellement. Leur statut ne doit pas être promu automatiquement à partir d'une autre preuve.

1. LAB-01 — HTTP + OpenAPI — **À EXÉCUTER manuellement**
2. LAB-02 — Mock Payment API — **À EXÉCUTER manuellement**
3. LAB-03 — Kong Gateway — **À EXÉCUTER manuellement** ; équivalent borné prouvé en CI
4. LAB-04 — OAuth/OIDC avec Keycloak — **À EXÉCUTER manuellement** ; équivalent borné prouvé en CI
5. LAB-05 — Gateway policies — **À EXÉCUTER manuellement** ; subset chargé/testé en CI
6. LAB-06 — mTLS — **À EXÉCUTER**
7. LAB-07 — OpenShift — **À EXÉCUTER**
8. LAB-08 — Observability — **À EXÉCUTER**
9. LAB-09 — Kafka + AsyncAPI — **À EXÉCUTER**
10. LAB-10 — Resilience — **À EXÉCUTER**
11. LAB-11 — FAPI architecture review — **À EXÉCUTER**
12. LAB-12 — MayaBank end-to-end complet — **À EXÉCUTER** ; la preuve CI actuelle ne couvre que Kong + Keycloak + Payment API

Convention manuelle : `À EXÉCUTER → EN COURS → VALIDÉ / BLOQUÉ`.

## Preuve runtime automatisée disponible

Une chaîne bornée est désormais **validée en GitHub Actions** :

```text
Keycloak 26.8.0
   ↓ OAuth2 client_credentials / RS256
Kong 3.9.3
   ↓ protected API
Payment API
```

Preuve :
- `evidence/ci/API-MANAGEMENT-E2E-2026-10-02.md`
- run `36984578912` — SUCCESS

Tests observés :
- bootstrap Keycloak ;
- scopes + audience ;
- rejet sans token ;
- création paiement via Kong ;
- correlation ID ;
- replay idempotent ;
- lecture paiement ;
- rejet d'une signature JWT altérée.

Cette preuve ne valide pas OpenShift, Kafka, mTLS/FAPI, HA ou production readiness.

La validation manuelle doit conserver : date, versions, commandes, résultats, erreurs, captures/preuves et conclusion d'architecture.
