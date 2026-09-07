# mTLS, DPoP et FAPI 2.0

## Pourquoi

Un bearer token volé peut être rejoué. Les mécanismes sender-constrained lient l'usage du token à un client/une clé.

## FAPI 2.0

Pour les API financières ou autres API à haute valeur, étudier :
- FAPI 2.0 Security Profile ;
- client authentication forte ;
- sender-constrained access tokens ;
- PAR ;
- DPoP ou mTLS selon le profil ;
- message signing lorsque requis.

Ne jamais déclarer un système « FAPI compliant » sans tests de conformité et périmètre explicite.
