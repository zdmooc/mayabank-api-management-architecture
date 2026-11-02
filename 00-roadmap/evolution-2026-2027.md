# Feuille de route d'évolution 2026–2027

Ce dépôt évolue par **profils runtime successifs**, plutôt que par un nouveau dépôt. Chaque profil réutilise les mêmes contrats (`apis/`) et consomme la plateforme partagée (ADR-011). Il n'est déclaré prouvé qu'après exécution, avec des preuves dans `evidence/` et une ligne dans la [matrice](../evidence/CLAIM-EVIDENCE-MATRIX.md).

Référence de départ : le commit `a791ae1` du 2026-10-23, état du dépôt avant cette feuille de route. Il est à étiqueter `v1.0` : `git tag -a v1.0 a791ae1 -m "v1.0" && git push origin v1.0`.

## Pourquoi ces priorités

Les grands comptes banque et assurance concentrent leurs efforts sur quelques sujets (revue de sources publiques, novembre 2026) :

| Moteur | Effet sur l'architecture API | Source |
|---|---|---|
| PSD3 / PSR (accord politique de novembre 2025, publication au JO attendue au second semestre 2026, application environ 21 mois après) | La performance et la disponibilité des API deviennent des obligations mesurées et publiées, avec une parité par rapport aux canaux propres de la banque | [MoFo](https://www.mofo.com/resources/insights/260430-psd3-and-the-payment-services-regulation-key-developments), [Treasury Management](https://treasury-management.com/articles/maturity-moment), [Finextra](https://finextra.com/the-long-read/1070/psd3-use-cases) |
| FIDA, open finance (assurance incluse) | API standardisées et tableaux de bord de consentement. Le calendrier est incertain : le texte est encore en négociation en 2026 | [Solutions Numériques](https://www.solutions-numeriques.com/avis-dexpert-fida-la-nouvelle-bataille-de-lassurance-se-joue-sur-la-donnee/), [Conseil de l'UE](https://data.consilium.europa.eu/doc/document/WK-4626-2026-INIT/en/pdf) |
| DORA (applicable depuis le 17 janvier 2025) | Journalisation des incidents, maîtrise des fournisseurs TIC tiers, y compris la plateforme d'API Management | [Didit](https://didit.me/fr/blog/api-gateways-dora-compliant-identity-services/) |
| API Management fédéré | Gouverner plusieurs gateways depuis un catalogue unique | [Axway](https://www.axway.com/de/node/201) |
| IA agentique / MCP | La gateway gouverne aussi les accès des agents (MCP, LLM) | [Kong](https://konghq.com/resources/videos/kong-ai-gateway-mcp-governance-agentic-ai) |

Ces dates sont réglementaires et susceptibles d'évoluer : elles sont à revérifier avant toute réutilisation.

## Profils, dans l'ordre

| # | Profil | Objectif | Livrables | Preuve attendue | Statut |
|---|---|---|---|---|---|
| P0 | Durcissement du socle | Aligner le code sur l'architecture déclarée | BOLA, idempotence par client et par payload, validation du contrat et de l'IBAN, consumer Kong par client, lint OpenAPI/AsyncAPI réel, tests de contrat | Marqueurs CI `PAYMENT_BOLA_OTHER_CLIENT_REJECTED`, `KONG_UNREGISTERED_CLIENT_REJECTED`, `KONG_RATE_LIMIT_PER_CONSUMER_ISOLATION`… | Voir la matrice |
| P1 | Performance et disponibilité (PSD3/PSR) | Mesurer et publier des SLI d'API | Test de charge via Kong, SLI p95 / taux d'erreur / disponibilité, rapport de performance périodique simulé | Résultats mesurés et versionnés, sans extrapolation vers la production | À FAIRE |
| P2 | FAPI 2.0 baseline | Sécurité haute exposition | mTLS client, tokens liés à l'émetteur (mTLS ou DPoP), PAR, ADR-007 mis à jour | Scénarios nominaux et négatifs (token rejoué sans la preuve de possession → refusé) | À FAIRE |
| P3 | API comme produit | Passer de la gateway à l'API Management | Catalogue et onboarding des consommateurs « as code », plans et quotas par consumer, cycle de dépréciation exercé | Onboarding d'un nouveau client sans modification manuelle de la gateway | À FAIRE |
| P4 | Événementiel | Relier les contrats API et événements | Publication de `PaymentStatusChanged` (pattern outbox), consommation de Kafka (sans le posséder, ADR-011) | Aucun événement perdu lors d'une indisponibilité simulée de Kafka | À FAIRE |
| P5 | Produit du marché | Prouver la neutralité vis-à-vis des éditeurs | Même contrat sur un second produit (Apigee, Azure APIM ou autre, selon les missions visées), dans un dépôt satellite si des identifiants cloud sont nécessaires | Le même jeu de tests E2E passe sur les deux implémentations | À DÉCIDER |
| P6 | Fédération et choix de plateforme | Instruire une décision défendable | ADR de choix de plateforme avec critères pondérés et score, inventaire multi-gateway | ADR accepté avec les options rejetées et leurs raisons | À FAIRE |
| P7 | Accès IA gouverné (MCP) | Étendre la gouvernance API aux agents | Route D-090 documentée comme consommateur, exposition MCP d'une API REST derrière la gateway | Accès agent authentifié, limité et tracé ; refus hors scope | EN COURS (D-090 opt-in) |

## Dette technique connue (hors profils)

| Sujet | Risque | Traitement prévu |
|---|---|---|
| Profil CRC : la Payment API a changé le 2026-11-02 | La preuve CRC du 2026-10-02 porte sur l'ancienne version | Rejouer `deploy-crc.sh` et `test-crc.sh` |
| Profil CRC : port d'administration Kong (8001) exposé par le Service, sans NetworkPolicy | Reconfiguration de la gateway possible depuis le cluster | Port de statut séparé, admin limité à localhost, NetworkPolicy deny-by-default |
| Profil CRC : consumer unique, sélectionné par `iss` | Pas de quota ni de traçabilité par client sur CRC | Reporter les consumers par `azp` de `runtime/e2e` |
| Clé publique du realm copiée dans la config Kong | Une rotation de clés côté Keycloak casse la gateway | Re-rendu automatisé ou validation JWKS (produit ou plugin) |
| Scripts CRC en `curl -k` | Vérification TLS désactivée dans les tests | Utiliser la CA du routeur CRC |
| Test OTel CRC : recherche de texte dans les logs du collector | Faux positif possible (traces d'un autre service) | Filtrer sur `service.name` ou sur un trace-id propagé |
| Erreurs émises par Kong (401, 413, 429) | Pas au format `application/problem+json` du contrat | Personnaliser les erreurs de la gateway ou documenter l'écart |
| Idempotence et paiements en mémoire | Perte au redémarrage, incohérence multi-réplicas | Hors périmètre du fixture : à traiter avec P4 (persistance) |
