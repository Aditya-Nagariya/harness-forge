# Production-readiness checklist

8 categories, rendered as the report's final section using the checklist block below.

1. **Error handling.** Every external call (network, disk, subprocess) has a handled failure path, not just a handled success path.
2. **Observability.** Failures are logged with enough context to diagnose without reproducing locally; no silent failures (see the silent-failure-hunter agent's exact patterns).
3. **Config.** No hardcoded environment-specific values (URLs, ports, credentials) that should be config/env-driven.
4. **Resilience.** Timeouts on every external call; retries with backoff where retrying is safe; rate/concurrency limits where an unbounded caller could overwhelm a dependency.
5. **Data / state.** Migrations are backward-compatible during a rolling deploy; no data-loss path on a partial failure.
6. **Lifecycle / deployment.** Graceful shutdown (in-flight requests finish or fail cleanly); health-check endpoint reflects real readiness, not just "process is up."
7. **Testing.** The changed behavior has a test that would fail if the fix/feature were reverted.
8. **Docs.** A new operational surface (new env var, new endpoint, new failure mode) is documented somewhere a future on-call engineer would find it.

## Checklist block (render this in the report's section 4, filled in)

```
[ ] Errors handled on every external call (network/disk/subprocess)
[ ] Failures logged with enough context to diagnose remotely
[ ] No hardcoded environment-specific config
[ ] Timeouts set on every external call
[ ] Retries (where safe) use backoff, not tight loops
[ ] Rate/concurrency limits where an unbounded caller could overwhelm a dependency
[ ] Migrations are backward-compatible during a rolling deploy
[ ] No data-loss path on partial failure
[ ] Graceful shutdown handles in-flight work
[ ] Health check reflects real readiness
[ ] Changed behavior has a test that fails on revert
[ ] New operational surface (env var/endpoint/failure mode) is documented
[ ] Build/test/lint commands from .claude/harness.env all pass
```
