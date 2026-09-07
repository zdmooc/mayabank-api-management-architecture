# OAuth 2.0 / OpenID Connect

## Rôles

- Resource Owner
- Client
- Authorization Server
- Resource Server

## Flows à connaître

- Authorization Code + PKCE : applications utilisateur.
- Client Credentials : machine-to-machine.
- Device Authorization : devices contraints, si besoin réel.

## Architecte

Décider :
- type de client ;
- scopes ;
- audiences ;
- token lifetime ;
- refresh tokens ;
- client authentication ;
- sender-constrained token si nécessaire ;
- révocation/introspection selon architecture ;
- séparation authentication / authorization métier.
