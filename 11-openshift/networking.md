# Networking OpenShift

Flux minimal :

```text
Internet / Corporate
  ↓
Load Balancer / WAF
  ↓
OpenShift Router / ingress
  ↓
API Gateway
  ↓
Service
  ↓
Pods
```

Décider explicitement où sont :
- TLS termination ;
- client certificate validation ;
- source IP ;
- WAF ;
- rate limit ;
- authentication.
