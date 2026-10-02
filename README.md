# MayaBank — API Management Solution Architecture

Référentiel professionnel et laboratoire différé pour apprendre, concevoir et challenger une architecture **API Management banque/assurance**.

## Positionnement visé

**Architecte Solution — API Management / Integration / Security — OpenShift / Kafka / Cloud**

Le dépôt est **vendor-neutral** : les principes d'architecture sont valables pour **Apigee, Kong, MuleSoft Anypoint, Axway Amplify** et autres plateformes. Les labs locaux privilégient **Kong Gateway + Keycloak + OpenShift Local/CRC** lorsqu'un produit exécutable localement est nécessaire.

## Livrables d'architecture directement démontrables

- [HLD — architecture de haut niveau](architecture/HLD.md)
- [LLD — design détaillé](architecture/LLD.md)
- [UML Component](diagrams/uml/component.puml)
- [UML Sequence — création paiement](diagrams/uml/sequence-payment-create.puml)
- [UML Deployment — OpenShift](diagrams/uml/deployment-openshift.puml)
- [OWASP API Security Top 10 — mapping architecture](security/OWASP-API-Security-Top10-2023.md)
- [Claim / Evidence Matrix](evidence/CLAIM-EVIDENCE-MATRIX.md)
- [API Management — Shared Platform CRC Runtime Evidence](evidence/crc/API-MANAGEMENT-SHARED-PLATFORM-CRC-2026-10-02.md)
- [OpenAPI Payment API](apis/openapi/payment-api.yaml)
- [AsyncAPI Payment Events](apis/asyncapi/payment-events.yaml)

Ces artefacts sont des **preuves de conception**. Le dépôt possède maintenant aussi une preuve runtime CI bornée **Kong + Keycloak + Payment API** : [API Management E2E Runtime Evidence](evidence/ci/API-MANAGEMENT-E2E-2026-10-02.md).

## Chaîne cible

```mermaid
flowchart LR
  C[Consumer / Channel / Partner] --> WAF[WAF / Edge]
  WAF --> GW[API Gateway]
  GW --> IAM[OAuth/OIDC Authorization Server]
  GW --> API[API / Microservice]
  API --> K[Kafka / Events]
  API --> DB[(Database)]
  GW --> OBS[Logs / Metrics / Traces]
  API --> OBS
  REG[API Catalog / Developer Portal] --> GW
  GOV[API Governance] --> REG
  CICD[CI/CD + Contract Testing] --> GW
```

## Ce qu'un Architecte Solution API Management doit savoir faire

- définir la stratégie API et les principes d'architecture ;
- distinguer API Gateway, API Management, ESB/iPaaS, service mesh et ingress ;
- concevoir une API REST/HTTP avec OpenAPI ;
- concevoir une API événementielle avec AsyncAPI ;
- gérer le cycle de vie : design, review, publish, secure, observe, deprecate, retire ;
- définir les politiques de sécurité OAuth/OIDC, mTLS, JWT, scopes, consentement, DPoP/FAPI selon le risque ;
- concevoir le north-south et l'east-west ;
- définir quotas, rate limits, timeouts, retries, circuit breakers et idempotence ;
- définir l'observabilité et les SLO ;
- intégrer OpenShift/Kubernetes, Kafka, IAM, SI legacy et cloud ;
- arbitrer Apigee vs Kong vs MuleSoft vs Axway ;
- définir gouvernance, RACI, standards, ADR et architecture de référence ;
- produire et défendre HLD, LLD, UML, threat model et décisions d'architecture ;
- expliquer les choix devant sécurité, production et métier.

## Standards de référence — baseline 2026

- OpenAPI Specification **3.2.1**
- AsyncAPI Specification **3.1.0**
- OAuth 2.0 + **RFC 9700**
- OpenID Connect
- PKCE
- mTLS / sender-constrained tokens selon les cas
- **FAPI 2.0** pour les API à haut niveau de sécurité
- **OWASP API Security Top 10 — 2023** comme baseline de revue
- OAuth 2.1 : à suivre comme **Internet-Draft**, pas comme RFC final dans cette baseline

## Parcours

1. [Roadmap](00-roadmap/README.md)
2. [Fondations API](01-foundations/README.md)
3. [API Design](02-api-design/README.md)
4. [API Lifecycle](03-api-lifecycle/README.md)
5. [API Security](04-api-security/README.md)
6. [Gateway Architecture](05-api-gateway/README.md)
7. [Comparaison plateformes](06-platforms/README.md)
8. [Gouvernance](07-governance/README.md)
9. [Observabilité](08-observability/README.md)
10. [Résilience & performance](09-resilience-performance/README.md)
11. [Event Driven / Kafka](10-event-driven/README.md)
12. [OpenShift](11-openshift/README.md)
13. [Banque / Open Banking](12-banking/README.md)
14. [Enterprise Integration](13-enterprise-integration/README.md)
15. [ADR](14-architecture-decisions/README.md)
16. [POC MayaBank](15-mayabank-poc/README.md)
17. [Entretien](16-interview-preparation/README.md)
18. [Labs à exécuter](labs/README.md)

## Règle de preuve

Les labs manuels historiques conservent leur propre statut `À EXÉCUTER` tant qu'ils ne sont pas rejoués individuellement. En parallèle, `runtime/e2e/` fournit désormais une **preuve CI exécutée avec succès** pour la chaîne Kong + Keycloak + Payment API. La [Claim / Evidence Matrix](evidence/CLAIM-EVIDENCE-MATRIX.md) reste la source de vérité.

## Architecture MayaBank

```mermaid
flowchart TD
  MOB[Mobile Banking] --> EDGE[API Edge]
  WEB[Web Banking] --> EDGE
  TPP[Partner / TPP] --> EDGE
  EDGE --> GW[API Management]
  GW --> AUTH[OIDC / OAuth Authorization Server]
  GW --> PAY[Payment API]
  GW --> CUST[Customer API]
  GW --> FRAUD[Fraud API]
  PAY --> KAFKA[Kafka]
  PAY --> CORE[Core Banking / Payment Hub]
  FRAUD --> KAFKA
  PAY --> DB[(Oracle/PostgreSQL)]
  GW --> OBS[Observability]
```

## Positionnement honnête

Ce dépôt démontre une capacité de **conception Solution Architecture** : HLD/LLD, contrats, UML, API security, ADR, intégration et gouvernance. Il démontre aussi en CI une chaîne runtime bornée **Keycloak 26.8.0 → Kong 3.9.3 → Payment API**, avec tests positifs/négatifs et idempotence.

La cible entreprise est désormais implémentée séparément sous `runtime/shared-platform/` : **Kong reste la plateforme spécialisée**, tandis que OIDC, OTel, secrets, GitOps et quality gates sont consommés depuis `shared-platform-services-openshift`. Ce profil est maintenant **CRC_RUNTIME_PROVEN_SHARED_PLATFORM_CONSUMER** sur OpenShift Local / CRC 4.22.7 : Kong consomme le realm OIDC partagé `mayabank`, route vers la Payment API et exporte des traces vers le collector OTel partagé.

Le dépôt ne remplace pas plusieurs années d'expérience de production sur Apigee, Kong, MuleSoft ou Axway et ne revendique ni HA, ni production readiness.
