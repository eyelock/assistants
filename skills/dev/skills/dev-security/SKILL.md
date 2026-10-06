---
name: dev-security
description: Security-first development - input validation, authentication, secrets management, and OWASP top 10 prevention. Use when writing or checking code that handles user input, uploads, logins, sessions, cookies, tokens or secrets, or when asked whether code is safe.
---

# Security-First Development

You apply these principles when writing or reviewing code to prevent common security vulnerabilities.

## Absent controls are findings

Most of what follows can be wrong in code that exists, or missing from code that should
have it. Writing or reviewing anything that handles logins, sessions, tokens, uploads, or
someone else's data, check for what is absent, not only for what is wrong:

- Authentication events (login success and failure, logout, reset requested, password
  changed) are logged with user, outcome and source, and never with the secret
- Authorization failures are logged
- Login, reset and other guessable endpoints are rate limited
- Every route that reads or changes a resource checks the caller owns it
- Uploads have a size limit; inputs have type, length and allowed-value checks
- A password change or reset ends every other session

Code you write is not done until each of these that applies is in it. In a review, each one
missing is a finding like any other.

## Reporting a review

Each finding gives `path:line` (line in the new version of the file; from a patch, count from
the hunk header `@@ -a,b +c,d @@`, where the first new-side line is `c`), a severity
(critical / high / medium / low), how an attacker uses it, and the fix. Things checked and
found sound get one line each, so the author knows they were looked at.

## Input Validation

### At system boundaries

Validate all input where it enters the system — API handlers, form submissions, file uploads, CLI arguments, message consumers.

- Whitelist allowed values rather than blacklisting dangerous ones
- Validate type, length, range, and format
- Reject unexpected fields — don't silently ignore extra data that could indicate an attack

### Injection prevention

- **SQL injection**: Use parameterized queries or prepared statements. Never concatenate user input into SQL strings.
  ```
  BAD:  query("SELECT * FROM users WHERE id = " + userId)
  GOOD: query("SELECT * FROM users WHERE id = ?", userId)
  ```
- **Command injection**: Never pass user input to shell commands. Use language-native libraries instead of shelling out. If you must shell out, use argument arrays, never string concatenation.
- **Path traversal**: Resolve file paths and verify they're within the expected directory. Reject `../` sequences. Use allowlists for permitted directories.
- **XSS**: Escape output in HTML contexts. Use framework-provided template escaping. Set `Content-Type` headers correctly. Use Content Security Policy headers.

### File uploads

- Validate file type by content (magic bytes), not by extension or MIME type from the client
- Enforce maximum file size at the web server level, not just application level
- Store uploads outside the web root
- Generate new filenames — never use the client-provided filename for storage

## Authentication and Authorization

### Authentication

- Use established libraries and protocols (OAuth 2.0, OpenID Connect) — don't build custom auth
- Hash passwords with bcrypt, scrypt, or argon2 — never MD5 or SHA for passwords
- Enforce minimum password complexity or use passphrase requirements
- Implement rate limiting on login endpoints to prevent brute force
- Use constant-time comparison for tokens and passwords to prevent timing attacks

### Session management

- Generate session tokens with a cryptographically secure random number generator
- Set appropriate cookie flags: `HttpOnly`, `Secure`, `SameSite=Strict`
- Expire sessions on the server side — don't trust client-side expiry alone
- Invalidate all sessions on password change

### Tokens sent by email (password reset, verification, magic links)

- 32 bytes from a cryptographically secure generator; store only a hash of the token
- Single use, with a short server-side expiry (an hour at most for a reset)
- The request endpoint answers the same whether or not the account exists, and is rate limited
- Look the token up by its hash; never compare a raw token with `==`

### Authorization

- Check permissions on every request, not just in the UI
- Default deny — explicitly grant access, don't try to enumerate what's blocked
- Verify the user owns the resource they're accessing (IDOR prevention): `GET /orders/{id}` must check the order belongs to the requesting user
- Log authorization failures — they may indicate an attack

## Secrets Management

### In code

- Never commit secrets to version control — not even "temporarily"
- Use environment variables or a secrets manager (AWS Secrets Manager, Vault, etc.)
- Add secret file patterns to `.gitignore`: `*.pem`, `*.key`, `.env`, `credentials.json`
- If a secret is accidentally committed, rotate it immediately — removing from git history isn't sufficient

### In configuration

- Use different secrets per environment (dev, staging, production)
- Rotate secrets regularly and ensure the application handles rotation gracefully
- Log secret access but never log secret values
- Minimum privilege: each service gets only the secrets it needs

### API keys

- Use separate keys for different consumers so you can revoke individually
- Set expiration on keys where possible
- Scope keys to minimum required permissions

## Transport Security

- Use TLS everywhere — not just for login pages
- Set HSTS headers to prevent protocol downgrade
- Pin certificates for service-to-service communication where appropriate
- Don't disable certificate verification, even in development — use local CA certs instead

## Dependency Security

- Keep dependencies updated — known vulnerabilities in old versions are the easiest attack vector
- Enable automated vulnerability scanning (Dependabot, Snyk, npm audit)
- Review new dependencies before adding: check maintenance status, contributor count, known issues
- Pin dependency versions in production — use lockfiles

## Logging and Monitoring

### What to log

- Authentication events: login, logout, failed attempts, password changes
- Authorization failures: access denied events
- Input validation failures: rejected requests
- Administrative actions: config changes, user management

### What NOT to log

- Passwords, tokens, API keys, session IDs
- Full credit card numbers, SSNs, or other PII
- Request bodies that may contain sensitive data — log a sanitized summary instead

### Monitoring

- Alert on unusual patterns: spike in auth failures, requests from new geographies, privilege escalation attempts
- Monitor for dependency vulnerabilities in CI/CD pipeline
- Regular security review of audit logs
