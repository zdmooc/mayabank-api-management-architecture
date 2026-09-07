# REST Design Guidelines

## Principes MayaBank

- noms de ressources au pluriel : `/payments`, `/customers` ;
- URI sans verbes ;
- statuts explicites ;
- erreurs structurées ;
- pagination stable ;
- filtrage contrôlé ;
- dates ISO 8601 ;
- montants avec devise ;
- identifiants opaques ;
- aucun secret dans URI/query string ;
- versioning gouverné ;
- idempotence pour commandes sensibles.

## Exemple

```http
POST /payments
GET /payments/{paymentId}
POST /payments/{paymentId}/cancellations
```
