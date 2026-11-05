# Acme HTTP API Style Guide

This guide is how every public Acme HTTP API is designed. Reviewers check new endpoints against it.

## 1. Resource naming

- Resources are plural nouns: `/invoices`, `/customers`, `/payment-methods`.
- Use kebab-case in paths. Never camelCase or snake_case in a path.
- Nest a resource under its parent only when it cannot exist without it: `/customers/{id}/payment-methods`.
- Never nest more than two levels deep. Use a filter instead: `/line-items?invoice_id=...`.
- Actions that are not CRUD become sub-resources with a verb: `POST /invoices/{id}/void`.
- Identifiers are opaque strings with a type prefix: `inv_8d2k1`, `cus_19ab`.
- Never expose database row numbers as identifiers.

## 2. HTTP methods

| Method | Use | Idempotent | Body |
|---|---|---|---|
| GET | Read one or many | Yes | None |
| POST | Create, or run an action | No, unless an Idempotency-Key is sent | Required |
| PATCH | Partial update | Yes | Required |
| PUT | Not used | - | - |
| DELETE | Remove | Yes | None |

- We do not use PUT. Full replacement has caused data loss when clients sent stale objects.
- PATCH bodies use JSON Merge Patch semantics: a field set to null is cleared, a missing field is untouched.

## 3. Status codes

| Code | When |
|---|---|
| 200 | Successful read or update that returns a body |
| 201 | Created; include a Location header |
| 202 | Accepted for asynchronous processing; include a link to the job |
| 204 | Success with no body (DELETE) |
| 400 | The request is malformed or fails validation |
| 401 | No or invalid credentials |
| 403 | Valid credentials, not allowed |
| 404 | Not found, or not visible to this caller |
| 409 | Conflict with current state (version mismatch, duplicate) |
| 422 | Not used; use 400 |
| 429 | Rate limited; include Retry-After |
| 500 | Our fault |
| 503 | Temporarily unavailable; include Retry-After |

- Return 404, not 403, when the caller must not learn that the resource exists.
- Never return 200 with an error in the body.

## 4. Field naming and types

- JSON fields are snake_case.
- Booleans read as questions: `is_active`, `has_children`. Never `active_flag`.
- Timestamps are RFC 3339 strings in UTC with a `_at` suffix: `created_at`, `voided_at`.
- Dates without a time use a `_on` suffix: `due_on`.
- Money is an object with integer minor units and an ISO 4217 currency: `{ "amount": 1250, "currency": "EUR" }`.
- Never send money as a float.
- Enumerations are lowercase snake_case strings, never integers.
- New enumeration values can appear at any time; document that clients must handle unknown values.
- Every object carries an `object` field naming its type: `"object": "invoice"`.

## 5. Errors

Every error response has this shape:

```json
{
  "error": {
    "type": "invalid_request",
    "code": "amount_too_small",
    "message": "Amount must be at least 50 cents.",
    "param": "amount",
    "request_id": "req_7Hq2"
  }
}
```

- `type` is one of `invalid_request`, `authentication`, `permission`, `not_found`, `conflict`, `rate_limit`, `internal`.
- `code` is stable and documented; clients branch on it.
- `message` is for humans and may change at any time.
- `param` names the offending field, when there is one.
- `request_id` matches the `Request-Id` response header.
- Validation errors report every invalid field at once in an `errors` array, not just the first.

## 6. Pagination

- Every list endpoint is paginated. There are no unpaginated lists.
- Use cursor pagination: `?limit=20&starting_after=inv_8d2k1`.
- `limit` defaults to 20 and is capped at 100.
- The response is `{ "object": "list", "data": [...], "has_more": true, "next_cursor": "..." }`.
- Do not return total counts by default; they are expensive. Offer `?include=total_count` where it is cheap.
- Sort order is stable and documented, newest first unless stated.

## 7. Filtering and sorting

- Filters are query parameters named after the field: `?status=open`.
- Range filters use bracket suffixes: `?created_at[gte]=2026-01-01`.
- Multiple values are comma separated: `?status=open,paid`.
- Sorting uses `?sort=created_at` or `?sort=-created_at` for descending.
- Only allow sorting on indexed fields.

## 8. Expansion

- Related objects are returned as IDs by default.
- Clients can ask for the full object with `?expand=customer`.
- Expansion is at most two levels deep: `?expand=customer.default_payment_method`.

## 9. Versioning

- The version is a date sent in the `Acme-Version` header: `Acme-Version: 2026-09-01`.
- An account is pinned to the version it first used.
- Adding a field, an endpoint, an optional parameter or an enumeration value is not breaking.
- Removing or renaming anything, changing a type, or making an optional parameter required is breaking and needs a new version.
- Every breaking change ships with a migration note in the changelog.

## 10. Idempotency

- POST requests accept an `Idempotency-Key` header.
- Keys are stored for 24 hours with the response they produced.
- A repeated key with the same body returns the stored response.
- A repeated key with a different body returns 409 with code `idempotency_key_reused`.

## 11. Authentication

- Clients authenticate with a secret key in the `Authorization: Bearer` header.
- Publishable keys can only call endpoints marked publishable.
- Never accept keys in query parameters.
- Restricted keys carry scopes; an endpoint documents the scope it needs.

## 12. Rate limiting

- Limits are per key and per endpoint group.
- Every response includes `RateLimit-Limit`, `RateLimit-Remaining` and `RateLimit-Reset` headers.
- A limited request returns 429 with `Retry-After`.

## 13. Asynchronous operations

- Operations that may take longer than 5 seconds return 202 with a job object.
- Job objects have `status` of `pending`, `running`, `succeeded` or `failed`.
- Clients poll `GET /jobs/{id}` or subscribe to the `job.completed` webhook.

## 14. Webhooks

- Event names are `resource.event` in the past tense: `invoice.paid`, `customer.deleted`.
- Payloads carry the full object as it was when the event happened.
- Every delivery is signed with a SHA-256 keyed hash of the payload in the `Acme-Signature` header, with a timestamp to stop replays.
- Deliveries retry with exponential backoff for 3 days.
- Receivers must answer within 10 seconds with a 2xx status.

## 15. Documentation

- Every endpoint has an OpenAPI description with an example request and response.
- Every error `code` an endpoint can return is listed on that endpoint.
- Descriptions say what the endpoint does, not how it is implemented.

## 16. Review checklist

- [ ] Paths are plural kebab-case nouns, at most two levels deep
- [ ] No PUT
- [ ] Fields are snake_case, timestamps end in `_at`, money is minor units plus currency
- [ ] Errors use the standard shape and document their codes
- [ ] Lists are cursor paginated with a capped limit
- [ ] Breaking changes are behind a new version with a migration note
- [ ] POST endpoints accept an Idempotency-Key
- [ ] The OpenAPI description has examples
