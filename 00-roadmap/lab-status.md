# Statut des labs

Un lab passe à « EXÉCUTÉ » seulement quand il a été rejoué individuellement, avec ses preuves dans `evidence/`. Si une chaîne runtime automatisée couvre déjà une partie de son objectif, le statut l'indique, sans revendiquer le lab complet.

| Lab | Statut | Couverture par les chaînes runtime |
|---|---|---|
| LAB-01 HTTP/OpenAPI | PARTIELLEMENT COUVERT | Contrat linté en CI (Redocly), réponses de l'API validées contre les schémas OpenAPI par les tests unitaires |
| LAB-02 Mock Payment API | PARTIELLEMENT COUVERT | Fixture `runtime/e2e/payment-api` (en mémoire), testé en CI |
| LAB-03 Kong Gateway | PARTIELLEMENT COUVERT | Kong 3.9.3 DB-less en CI (`runtime/e2e`) et sur CRC (`runtime/shared-platform`) |
| LAB-04 OAuth/OIDC Keycloak | PARTIELLEMENT COUVERT | `client_credentials`, audience, scopes, rejets 401/403 en CI. Authorization Code + PKCE non couvert |
| LAB-05 Policies | PARTIELLEMENT COUVERT | Correlation-ID, rate limit par consumer (429 + isolation), taille de payload (413), consumers par client en CI |
| LAB-06 mTLS | À EXÉCUTER | — |
| LAB-07 OpenShift | PARTIELLEMENT COUVERT | Profil CRC 4.22.7 démontré en octobre (ancienne version) ; profil Kind démontré en CI en novembre ; CRC durci à retester |
| LAB-08 Observability | PARTIELLEMENT COUVERT | Traces Kong vers le collector OTel partagé sur CRC. Pas de SLO ni de métriques mesurées |
| LAB-09 Kafka/AsyncAPI | À EXÉCUTER | Contrat AsyncAPI validé par le parser officiel, aucun runtime |
| LAB-10 Resilience | À EXÉCUTER | — |
| LAB-11 FAPI architecture | À EXÉCUTER | — |
| LAB-12 MayaBank end-to-end | À EXÉCUTER | — |

Source de vérité : [Claim / Evidence Matrix](../evidence/CLAIM-EVIDENCE-MATRIX.md).
