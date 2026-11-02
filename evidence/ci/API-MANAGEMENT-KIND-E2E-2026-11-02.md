# Preuve E2E Kubernetes Kind — 2 novembre 2026

**Niveau :** CI_KIND_RUNTIME_PROVEN_E2E (GitHub Actions, runner Ubuntu seulement)
**Commit testé :** ef98c0fab377b81e56730cb16e08b3783e2ef23f

## Exécutions sur le même commit

- [Kind E2E #41444307927](https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/41444307927) — SUCCESS
- [Docker Compose E2E #41444307932](https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/41444307932) — SUCCESS
- [Contrats et sécurité #41444307974](https://github.com/zdmooc/mayabank-api-management-architecture/actions/runs/41444307974) — SUCCESS

## Périmètre exécuté

Déploiements et Services Kubernetes sur Kind mono-nœud : Keycloak 26.8.0,
Kong OSS 3.9.3 DB-less et Payment API Python/Flask. Construction et import
de l'image Payment API dans Kind, bootstrap Keycloak, rendu de la config Kong,
puis exécution du script de tests E2E.

## Marqueurs observés dans les logs Kind

```text
KEYCLOAK_E2E_BOOTSTRAP=PASS
KONG_DECLARATIVE_CONFIG_RENDER=PASS consumers=4
KIND_KONG_ADMIN_SERVICE_ISOLATED=PASS
KONG_ADMIN_READY=PASS
KONG_UNREGISTERED_CLIENT_REJECTED=PASS
PAYMENT_IDEMPOTENCY_REPLAY=PASS
PAYMENT_IDEMPOTENCY_KEY_REUSE_REJECTED=PASS
PAYMENT_TWO_WRITERS_ISOLATED=PASS
PAYMENT_IBAN_CHECKSUM_REJECTED=PASS
PAYMENT_BOLA_OTHER_CLIENT_REJECTED=PASS
PAYMENT_WRONG_AUDIENCE_REJECTED=PASS
KONG_RATE_LIMIT_429=PASS
KONG_RATE_LIMIT_PER_CONSUMER_ISOLATION=PASS
KONG_INVALID_SIGNATURE_REJECTED=PASS
API_MANAGEMENT_E2E_RUNTIME=PASS
MAYABANK_KIND_RUNTIME=PASS
```

## Limites

- Aucune exécution sur le Dell / Docker Desktop / WSL2 de l'utilisateur.
- Aucune nouvelle exécution sur OpenShift CRC. La preuve CRC historique date du 2 octobre 2026.
- Le Service Kong Kind n'expose que 8000 ; l'accès d'administration par
  port-forward de pod ne démontre pas une NetworkPolicy ou un pentest.
- HTTP localhost, pas de preuve TLS, mTLS/FAPI, rotation JWKS, haute disponibilité,
  stockage durable, quotas distribués, production readiness ou conformité bancaire.
