# Architecture cible MayaBank

## Contextes

- Mobile/Web : clients de banque.
- Partners/TPP : consommateurs externes.
- Payment API : façade métier.
- Payment Hub : système de paiement.
- Fraud : consommateur d'événements.
- Kafka : événementiel.
- API Management : sécurité, exposition, quota, observabilité.
- IAM : identités clients/applications.
- OpenShift : runtime.

## Flux de création paiement

1. Client obtient un token.
2. Client appelle `POST /payments` avec `Idempotency-Key`.
3. Gateway valide la sécurité et applique les policies.
4. Payment API valide l'autorisation métier.
5. Paiement est transmis au Payment Hub.
6. Un événement est publié.
7. Fraud/Notification/Reconciliation consomment l'événement.
8. Le client peut consulter l'état.
