# 11 — API Management sur OpenShift

## Architecture cible de lab

La cible ne redéploie plus toutes les capacités transverses dans le dépôt API Management.

```text
OpenShift Local / CRC
├── shared-observability
│   └── OpenTelemetry Collector              [CONSUME_SHARED]
├── keycloak-system
│   └── RHBK / Keycloak + realm mayabank     [CONSUME_SHARED]
└── mayabank-api
    ├── Kong Gateway                         [SPECIALIZED_PLATFORM]
    └── Payment API fixture                  [PRODUCT_OWNED / TEST FIXTURE]
```

Profil exécutable : `runtime/shared-platform/`.

Le runtime Keycloak/RHBK reste implémenté par `zdmooc/keycloak-enterprise-roadmap-v7`; la plateforme commune porte le contrat et le realm partagé. Kong reste propriétaire de ses routes, plugins et policies.

## Deux modes conservés

### Standalone CI

```text
Keycloak -> Kong -> Payment API
```

Mode : `DEDICATED_FOR_TEST`.

But : reproductibilité GitHub Actions indépendante.

### Shared Platform CRC

```text
Shared Keycloak/OIDC -> Kong -> Payment API
Shared OTel <- Kong traces
```

Mode : cible entreprise / consommation L2.

Statut actuel : `IMPLEMENTED / STATIC_VALIDATED`; runtime CRC pending.

## Questions architecte

- gateway partagé ou dédié ?
- namespaces et isolation ?
- route/ingress/gateway API ?
- TLS termination où ?
- secrets ?
- NetworkPolicy ?
- HPA ?
- PDB ?
- multi-AZ ?
- GitOps ?
- observabilité ?
- quelles capacités sont `CONSUME_SHARED` vs `SPECIALIZED_PLATFORM` ?
