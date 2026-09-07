# Roadmap Architecte Solution API Management

## Priorités

| Domaine | Priorité | Niveau cible /7 |
|---|---:|---:|
| API architecture & design | Indispensable | 6 |
| API security OAuth/OIDC/mTLS | Indispensable | 6 |
| API Gateway / API Management | Indispensable | 6 |
| Governance & lifecycle | Indispensable | 6 |
| OpenAPI | Indispensable | 6 |
| Observability / SLO | Indispensable | 5 |
| Resilience / performance | Indispensable | 5 |
| OpenShift / Kubernetes integration | Indispensable | 6 |
| Kafka / AsyncAPI | Important | 5 |
| FAPI 2.0 / banking security | Important banque | 5 |
| Apigee / Kong / MuleSoft / Axway | Important | 4-5 |
| Developer portal / API products | Important | 4 |
| Service mesh | Important | 4 |
| Monetization | Secondaire banque interne | 2-3 |

## Parcours recommandé

```text
HTTP/REST
  ↓
OpenAPI
  ↓
API Design
  ↓
Gateway
  ↓
OAuth/OIDC/mTLS
  ↓
Lifecycle + Governance
  ↓
Observability + SLO
  ↓
Resilience
  ↓
OpenShift
  ↓
Kafka/AsyncAPI
  ↓
FAPI 2.0 / Open Banking
  ↓
Architecture d'entreprise
```

## Objectif

Atteindre **5-6/7** sur architecture, sécurité, gouvernance et intégration, sans viser un rôle d'administrateur produit expert.
