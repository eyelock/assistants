---
name: http-api
description: Acme's HTTP API conventions.
---

# HTTP API conventions

Follow these rules for every endpoint in the public API.

## Resources

- Plural nouns for collections: `/invoices`, `/customers`
- Nest at most one level: `/customers/{id}/invoices`, never deeper
- IDs are opaque strings with a type prefix: `inv_8f2k`, `cus_91ma`

## Methods and status codes

| Method | Use | Success |
|---|---|---|
| GET | read | 200 |
| POST | create | 201, with a Location header |
| PATCH | partial update | 200 |
| DELETE | remove | 204 |

## Fields

- `snake_case` for every field
- Timestamps are RFC 3339 strings in UTC, named `*_at`
- Money is an integer count of the smallest unit plus a `currency` field

## Errors

Every error body follows [errors.md](references/errors.md).

For pagination, webhooks and everything else, see the references folder.
