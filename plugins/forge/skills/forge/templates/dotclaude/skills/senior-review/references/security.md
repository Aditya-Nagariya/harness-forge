# Security checklist

12 categories. A search hit is a lead, not a finding — confirm untrusted input actually reaches the sink before reporting.

1. **Injection.** SQL/NoSQL/template/LDAP/command injection — any query/template/shell command built by string concatenation with external input. Mongo-specific: object-valued query params can smuggle operators (`{"$gt": ""}`) — validate types, not just presence.
2. **XSS.** Unescaped user input rendered into HTML/JS context (skip if there's no browser-rendered frontend — say so explicitly rather than silently omitting the section).
3. **AuthN.** Missing or bypassable authentication on a new endpoint/handler.
4. **AuthZ / IDOR.** Endpoint checks "is logged in" but not "is authorized for *this* resource" — the classic insecure-direct-object-reference gap (fetching `/orders/123` without checking the order belongs to the caller).
5. **Secrets.** Hardcoded credentials, API keys, tokens in source or committed config; secrets logged in plaintext.
6. **Crypto.** Weak/deprecated algorithms, home-rolled crypto, predictable IVs/nonces, missing integrity checks.
7. **SSRF.** Outbound requests to a URL derived from user input, fetched without an allowlist.
8. **Deserialization.** Untrusted data through a format/library capable of executing code (unsafe YAML load, `pickle`, PHP `unserialize`).
9. **File handling.** Path traversal via unvalidated user-supplied paths; unrestricted file upload (type/size/destination).
10. **Supply chain.** New dependency with no version pin, from an unfamiliar registry, or with known CVEs.
11. **Transport/CORS.** Missing TLS enforcement, overly permissive CORS (`*` with credentials), missing security headers.
12. **Mass assignment.** An update endpoint that blindly binds a whole request body to a model, allowing a client to set fields it shouldn't (e.g. `role: admin`).

Closing rule: **a search hit is a lead, not a finding** — trace it to confirm reachability before writing it up as a vulnerability.
