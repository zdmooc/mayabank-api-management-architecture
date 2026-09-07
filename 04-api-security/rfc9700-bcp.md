# RFC 9700 — OAuth 2.0 Security BCP

Baseline MayaBank :

- Authorization Code avec PKCE pour clients utilisateur ;
- redirect URIs strictes ;
- pas d'Implicit Grant pour nouvelles architectures ;
- éviter Resource Owner Password Credentials ;
- protection contre mix-up et redirections ouvertes ;
- protection des refresh tokens ;
- validation stricte issuer/audience/signature/expiration ;
- secrets et clés gérés dans une solution dédiée.

Toujours confronter l'implémentation au RFC et aux capacités réelles de l'Authorization Server.
