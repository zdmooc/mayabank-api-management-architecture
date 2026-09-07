# Modèle d'erreur

Exemple de contrat :

```json
{
  "type": "https://mayabank.example/problems/payment-rejected",
  "title": "Payment rejected",
  "status": 422,
  "code": "PAYMENT_REJECTED",
  "correlationId": "a6b...",
  "detail": "Payment cannot be executed."
}
```

Ne jamais exposer stack traces, SQL, secrets ou détails internes.
