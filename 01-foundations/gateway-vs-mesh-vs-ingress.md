# Gateway vs Ingress vs Service Mesh

| Besoin | API Gateway | Ingress | Service Mesh |
|---|---|---|---|
| API products | Oui | Non généralement | Non |
| Developer portal | Oui | Non | Non |
| OAuth policies | Oui | Variable | Possible mais autre usage |
| Quotas consommateurs | Oui | Limité | Non typique |
| North-south | Oui | Oui | Possible |
| East-west | Possible | Non | Oui |
| mTLS service-to-service | Variable | Non typique | Oui |
| API analytics | Oui | Limité | Télémétrie service |

Décision architecte : ne pas empiler trois couches ayant les mêmes responsabilités sans justification.
