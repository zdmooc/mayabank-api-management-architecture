# FAPI 2.0 — vue Architecte

Chaîne conceptuelle :

```text
Client / TPP
  ↓
Authorization Server
  ├─ strong client authentication
  ├─ PAR
  └─ sender constrained tokens
       ↓
API Gateway / Resource Server
       ↓
Payment API
```

## Important

FAPI n'est pas « OAuth avec deux policies en plus ».  
Il impose un profil d'interopérabilité et de sécurité précis.

Un POC pédagogique ne doit jamais être présenté comme certification FAPI.
