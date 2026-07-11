# Severity scale

The single source of truth for severity, cited by `senior-review`, `harness-audit`, and any code-review agent in this harness — change it once here, every consumer picks it up. Rate by *impact × likelihood × exploitability*, not by how interesting the finding is.

| Tier | Meaning |
|---|---|
| 🔴 **Critical** | Exploitable now, or a guaranteed production failure. Blocks shipping. |
| 🟠 **High** | Serious, but gated by some precondition (a specific config, an edge-case input). Still blocks shipping. |
| 🟡 **Medium** | Real risk, but limited blast radius or harder to trigger. Worth fixing, not necessarily blocking. |
| 🟢 **Low** | Hardening, defense-in-depth, or maintainability. Author's judgment call. |

Gate mapping: any 🔴 or 🟠 finding is a blocker for `/ship`'s gate step and for a code-reviewer agent's verdict; 🟡/🟢 are "consider," never auto-blocking.

## Instant-fail patterns (short-circuit straight to 🔴, regardless of the rest of the diff)

Keep this list project-specific and small — a handful of patterns that are *always* wrong here, not a general style guide:

- A hardcoded secret, API key, or credential in source.
- Missing `await` on an async call whose result matters (silent unawaited coroutine).
- A raw, string-built database query containing untrusted input (SQL/NoSQL injection).
- Debug prints, breakpoints, or commented-out blocks of code left in a diff meant to ship.
- A stub/TODO with no ticket or tracked task reference, on a path that's about to ship.

(Add your own project-specific instant-fail rows here as you discover them — e.g. a specific multi-tenant isolation invariant, a compliance-mandated pattern. Keep the list short; a long list stops being instantly-recognizable.)
