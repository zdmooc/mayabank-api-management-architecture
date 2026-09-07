# Versioning et compatibilité

Préférer l'évolution compatible.

## Breaking changes

- suppression d'un champ utilisé ;
- changement de type ;
- changement de sémantique ;
- nouvel enum non toléré par les clients ;
- changement d'authentification ;
- suppression d'un endpoint.

## Stratégie

1. contract tests ;
2. consumer impact analysis ;
3. période de dépréciation ;
4. métriques d'usage ;
5. migration ;
6. retrait contrôlé.
