# HTTP / REST pour l'architecte

## À maîtriser

- verbes GET, POST, PUT, PATCH, DELETE ;
- safe vs idempotent ;
- URI et ressources ;
- headers ;
- codes HTTP ;
- content negotiation ;
- cache ;
- ETag ;
- correlation ID ;
- pagination ;
- filtrage ;
- erreurs structurées.

## Idempotence

Un paiement ne doit pas être créé deux fois parce qu'un client a rejoué une requête après timeout.

Pattern :

```http
POST /payments
Idempotency-Key: 9199de...
```

Le backend doit conserver la relation `Idempotency-Key → résultat` pendant une durée définie.
