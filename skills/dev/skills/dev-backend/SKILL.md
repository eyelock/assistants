---
name: dev-backend
description: Backend development approach — API design, data flow, error handling, and service architecture patterns.
---

# Backend Development

You apply these principles when designing and building backend services, APIs, and data processing systems.

## API Design

### REST conventions

- Use nouns for resources, HTTP verbs for actions: `GET /users/{id}`, `POST /orders`
- Return appropriate status codes: 200 (ok), 201 (created), 204 (no content), 400 (bad request), 404 (not found), 409 (conflict), 500 (server error)
- Use plural resource names: `/users` not `/user`
- Nest sub-resources: `/users/{id}/orders` not `/user-orders?user_id=123`
- Version the API in the URL: `/v1/users` — keeps it explicit and easy to route

### Request/response patterns

- Accept and return JSON with consistent field naming (camelCase or snake_case — pick one, be consistent)
- Always return a structured error response, not raw strings:
  ```json
  { "error": { "code": "VALIDATION_FAILED", "message": "Email is required", "field": "email" } }
  ```
- Use pagination for list endpoints: `?page=1&per_page=20` or cursor-based for large datasets
- Include `total_count` in paginated responses so clients know the full size

### Idempotency

- PUT and DELETE must be idempotent — calling them twice produces the same result
- For non-idempotent operations (payment, email send), accept an idempotency key from the client
- Return the cached result on duplicate idempotency keys, don't re-execute

## Data Flow

### Validation

- Validate at the boundary — where data enters the system (API handler, message consumer, CLI input)
- Internal code trusts validated data — don't re-validate deep in the stack
- Parse, don't validate: convert raw input into typed domain objects at the boundary, then pass typed objects inward

### Database access

- Use transactions for operations that must be atomic
- Keep transactions short — do validation and computation outside the transaction, only wrap the writes
- Use database constraints (unique, foreign key, not null) as the last line of defense — don't rely solely on application-level checks
- Index columns that appear in WHERE clauses and JOIN conditions
- Watch for N+1 queries — batch or join instead of looping

### Configuration

- Load from environment variables at startup, not scattered through the code
- Validate all required config at startup — fail fast with a clear message, not halfway through serving requests
- Use sensible defaults where possible, require explicit config only for environment-specific values (database URL, API keys)

## Error Handling

### Principles

- Return errors, don't swallow them — every error should either be handled or propagated
- Wrap errors with context as they travel up the stack: `"creating order: inserting row: connection refused"`
- Log at the point of handling, not at the point of creation — avoids duplicate log entries
- Distinguish between client errors (4xx — their problem) and server errors (5xx — our problem)

### Retries and resilience

- Retry only on transient failures (network timeout, 503) — never retry on validation errors or auth failures
- Use exponential backoff with jitter to avoid thundering herd
- Set a maximum retry count — infinite retries mask real failures
- Use circuit breakers for external dependencies — stop calling a dead service

### Graceful degradation

- If a non-critical dependency is down, serve what you can and note what's missing
- Health check endpoints should distinguish between "ready to serve" and "fully healthy"
- Shutdown gracefully: stop accepting new requests, finish in-flight work, then exit

## Service Architecture

### Keep it simple

- Start with a monolith — extract services only when you have a clear reason (independent scaling, different team ownership, different deployment cadence)
- A function call is simpler than a network call. Don't add a message queue between two things in the same process
- If you have fewer than 3 services, you probably don't need service discovery or an API gateway

### Boundaries

- Each service owns its data — no shared databases between services
- Communicate via well-defined APIs or events, not by reading each other's tables
- Define clear contracts (OpenAPI, protobuf, JSON schema) at service boundaries

### Observability

- Structured logging with consistent fields: timestamp, level, request_id, user_id, message
- Propagate request/correlation IDs across service boundaries
- Log at decision points (handled error, retried, circuit opened), not at every function entry/exit
- Metrics for the things that matter: request rate, error rate, latency percentiles (p50, p95, p99)
