# eyelock/mcp-toolkit Reference

Source: /Users/david/Storage/Workspace/eyelock/mcp-toolkit
Docs: /Users/david/Storage/Workspace/eyelock/mcp-toolkit/docs/

## Purpose

Production-ready MCP server boilerplate. Reference implementation of the full
MCP spec. Use as implementation guide and debugging resource.

## Key Documentation

- docs/mcp-reference.md   — spec-to-implementation mapping
- docs/getting-started.md — setup, running, MCP Inspector
- docs/tool-delegation.md — delegation pattern (local-only/delegate-first/delegate-only)
- docs/hooks.md           — hook system design and RFC 2119 requirement levels

## Transport Abstraction

Single interface supporting stdio and HTTP/SSE.
CLI flags: --http, --port, --host, --token
Switchable without code changes.

Stdio: local dev, MCP Inspector, Claude Desktop
HTTP/SSE: remote deployment, bearer token auth

## Tool Delegation Pattern

local-only (default): self-reliant, never delegate to LLM
delegate-first: try LLM via sampling, fall back locally on failure
delegate-only: require delegation, error if sampling unavailable

## Debugging

MCP Inspector: make mcp (visual testing of tools, resources, prompts)
Local validation: pnpm build && pnpm check && pnpm typecheck && pnpm test
Server identity: canonical name + environment tags (env=development, team=platform)
