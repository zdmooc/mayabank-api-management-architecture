# 01 — Fondations API Management

## API Gateway ≠ API Management

**API Gateway** : composant runtime qui reçoit, sécurise, filtre et route les appels.  
**API Management** : capacité plus large incluant design, publication, portail, sécurité, politiques, analytics, lifecycle et gouvernance.

```text
Consumer
  ↓
API Management plane
  ├─ Catalog
  ├─ Products
  ├─ Portal
  ├─ Policies
  ├─ Analytics
  └─ Governance
       ↓
Gateway runtime
       ↓
Backend APIs
```

## À ne pas confondre

- API Gateway : contrôle north-south des API.
- Ingress Controller : exposition réseau Kubernetes ; fonctions API souvent plus limitées.
- Service Mesh : trafic service-to-service/east-west.
- ESB : intégration et médiation historique.
- iPaaS : intégration SaaS/cloud/workflows/connectors.
- WAF : protection HTTP en périphérie.
- Load Balancer : distribution réseau/L4-L7.
