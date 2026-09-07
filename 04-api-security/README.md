# 04 — API Security

## Défense en profondeur

```text
Internet/Partner
  ↓
DDoS / WAF
  ↓
TLS
  ↓
API Gateway
  ├─ OAuth/OIDC validation
  ├─ mTLS / sender constraint si requis
  ├─ schema validation
  ├─ rate limit
  ├─ threat protection
  └─ audit
       ↓
Backend authorization
       ↓
Data controls
```

Le gateway ne doit pas devenir l'unique mécanisme d'autorisation métier.
