# 08 — Observability

Pour chaque appel :

```text
consumer → edge → gateway → service → dependency
             └──── correlation / trace ────┘
```

## Golden signals

- latency ;
- traffic ;
- errors ;
- saturation.

## API metrics

- requests/s ;
- p50/p95/p99 latency ;
- 4xx/5xx ;
- auth failures ;
- rate-limit hits ;
- backend timeout ;
- consumer/product ;
- endpoint ;
- version ;
- business outcome lorsque pertinent.
