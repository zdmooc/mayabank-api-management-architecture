# D-090 — TradeOps governed AI route on canonical Kong

Status: **OPT-IN PROFILE / CRC RUNTIME EVIDENCE PENDING**

Ownership remains unchanged:

- Shared Identity / realm `mayabank`: Shared Platform contract + Keycloak specialist runtime;
- Kong 3.9.3: API Management specialized platform;
- AI Access policy + LiteLLM lab: TradeOps until D-090 G5;
- Shared OTel: Shared Platform.

Target path:

```text
TradeOps genai-api
 -> tradeops-ai client_credentials
 -> Shared Keycloak / mayabank
 -> canonical Kong /ai
 -> ai-access-policy.tradeops.svc:8020
 -> LiteLLM
 -> approved real model
```

The existing Payment API route is unchanged by default. The AI service block is rendered only when:

```bash
D090_AI_ACCESS_ENABLED=true bash runtime/shared-platform/scripts/render-kong-config.sh
```

Recommended CRC command after TradeOps `ai-access-policy` is Ready:

```bash
bash runtime/shared-platform/scripts/enable-d090-ai-access-crc.sh
```

The enable script proves only gateway activation and the unauthenticated 401 boundary. It does not prove a real model call.
