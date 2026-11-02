# MayaBank — profil Kubernetes Kind

Ce profil utilise **Docker Desktop + Kind**, sans CRC/OpenShift. Il crée un
cluster Kubernetes mono-nœud avec Keycloak 26.8.0, Kong OSS 3.9.3 et la
Payment API, puis rejoue la même chaîne E2E que Docker Compose.

## Préparer Kind (WSL2 ou Linux)

```bash
kind create cluster --name mayabank-api
bash runtime/kind/run-kind.sh
```

Prérequis : Docker Desktop démarré avec intégration WSL2, `kind`, `kubectl`,
`jq`, `curl`, `python3`. Le script crée des secrets **éphémères** pour les
clients Keycloak et l'administrateur. N'utilisez pas de secrets de production.

Le script compile une image Payment API, la charge dans Kind, déploie les
manifestes, utilise `kubectl port-forward` vers les Services et **uniquement
vers le pod** pour l'Admin API Kong, puis rejoue les tests E2E.

## Preuves attendues

- `KIND_KONG_ADMIN_SERVICE_ISOLATED=PASS` — port Admin 8001 absent du Service
- `PAYMENT_TWO_WRITERS_ISOLATED=PASS` — deux clients, même clé, paiements distincts
- `KONG_UNREGISTERED_CLIENT_REJECTED=PASS`
- `KONG_RATE_LIMIT_PER_CONSUMER_ISOLATION=PASS`
- `MAYABANK_KIND_RUNTIME=PASS`

Le workflow `.github/workflows/kind-e2e.yml` fournit des preuves reproductibles
sur runner Linux lorsque son résultat est vert. Il ne constitue **pas** une preuve
de fonctionnement sur le poste Dell ni sur OpenShift CRC.

## Limites

HTTP localhost via port-forward, **sans preuve TLS** ; un seul replica Kong
avec rate-limit `local`, paiement en mémoire, aucun test HA/DR, Kafka ou
NetworkPolicy multi-namespace. Les ressources OpenShift `Route`,
`BuildConfig` et `ImageStream` ne sont pas testées sur Kind.

Pour supprimer ce cluster de laboratoire :

```bash
kind delete cluster --name mayabank-api
```
