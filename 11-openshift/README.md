# 11 — API Management sur OpenShift

## Architecture cible de lab

```text
OpenShift
├── api-gateway
│   └── Kong
├── identity
│   └── Keycloak
├── mayabank
│   └── payment-api
└── observability
```

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
