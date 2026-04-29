# MCP Specification Reference

Spec: https://modelcontextprotocol.io/specification/2025-03-26

## Core Primitives

### Tools
Functions the model can call. Input schema defined as JSON Schema.
Registration: central handler with Zod schema as source of truth.

### Resources
Data the model can read via URI. Static or templated (RFC 6570 URI templates).

### Prompts
Reusable message templates with arguments. Context-aware composition.

### Sampling
Server requests the host LLM to generate a completion.
Used when the server needs the model to make a decision.
Requires client capability check before use.

### Elicitation
Structured user input collection. Multi-field forms with JSON Schema validation.
Requires client capability check before use.

## Protocol Features

### Session State
State machine: uninitialized → initialized → ready → working
Enforce transitions; reject out-of-order messages.

### Progress
Long-running operation updates via progress notifications.

### Cancellation
Client can cancel in-flight requests. Server must handle cleanup.

### Pagination
Cursor-based pagination for list operations.

### Logging
RFC 5424 structured logging. Levels: debug, info, notice, warning, error,
critical, alert, emergency. Two transports: stderr and MCP protocol logging.

## Ping
Server availability check. Respond promptly.
