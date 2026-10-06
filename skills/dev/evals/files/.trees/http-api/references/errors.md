# Errors

Every error response has this body:

```json
{ "error": { "code": "invoice_not_found", "message": "No invoice inv_8f2k.", "request_id": "req_123" } }
```

- `code` is stable and snake_case; clients branch on it, never on `message`
- 400 for a malformed request, 422 for a well-formed request that fails validation
- 404 for a resource the caller cannot see, even when it exists
