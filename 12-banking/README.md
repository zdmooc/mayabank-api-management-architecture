# Banque / Open Banking — intégration et sécurité API

Le métier **PSU, AISP, PISP, ASPSP, consentement, initiation et états financiers** appartient exclusivement au [référentiel métier Open Banking/DSP2](https://github.com/zdmooc/banking-payments-business-architecture/blob/main/14-reglementation/OPEN_BANKING_DSP2_FONCTIONNEL.md).

Ce chapitre du dépôt API Management ne maintient pas une seconde liste de règles métier. Il porte sur les **contrats d'intégration et les contrôles d'API** dans les laboratoires et architectures d'API Management, sans revendiquer certification FAPI ou conformité DSP2 effective.

## Points de conception API à tester

- Identité du TPP, authentification client et autorisations réelles des appels : vérifier le statut métier en amont, puis appliquer le modèle de sécurité de l'API.
- `OAuth2/OIDC`, `FAPI 2.0` lorsque le profil est applicable, `mTLS`, `DPoP` ou contraintes cryptographiques adaptées à l'écosystème.
- Consentement et scopes : les permissions applicatives ne créent pas de nouveaux droits de paiement.
- Anti-rejeu, idempotence, corrélation technique, statuts HTTP, version d'API et gestion des callbacks/webhooks.
- Journal d'audit minimisé ; protection IBAN, identité, secret, tokens, données de compte.
- Quotas, rate limits et disponibilité, sans confondre délai d'une réponse `HTTP 202` avec exécution ou règlement.
- Résilience du gateway et plan de continuité, dont cas où l'interface externe est indisponible mais le paiement demeure en `UNKNOWN`.

**Cas d'étude technique MayaBank** : initiation, consultation de statut, informations de compte, notifications et erreur API sur données synthétiques. Voir [POC](../15-mayabank-poc/README.md) et [FAPI](fapi-architecture.md) pour la réalisation ; la règle métier reste au dépôt central.

[Version historique du chapitre](https://github.com/zdmooc/mayabank-api-management-architecture/blob/24b2bf42eaf4e0155bc019b50e00181edabd3a30/12-banking/README.md).
