# REST vs Events

| Besoin | REST | Event |
|---|---|---|
| réponse immédiate | Oui | Non naturellement |
| query | Oui | Mauvais choix |
| fan-out | Limité | Excellent |
| découplage temporel | Faible | Fort |
| audit stream | Variable | Fort |
| orchestration synchrone | Oui | Non |
| propagation d'état | Possible | Excellent |

Éviter le dogme « tout event-driven ».
