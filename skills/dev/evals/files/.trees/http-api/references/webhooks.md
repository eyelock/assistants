# Webhooks

- Event names are `<resource>.<past-tense verb>`: `invoice.paid`, `customer.deleted`
- Every delivery is signed: `Acme-Signature: t=<unix>,v1=<hex HMAC-SHA256 of "t.body">`
- Retries back off exponentially for up to 3 days; receivers must be idempotent on the event `id`
- The payload carries the full resource as it was when the event happened, not a diff
