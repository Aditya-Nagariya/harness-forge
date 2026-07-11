# Performance checklist

7 categories. Quantify impact wherever you can — "this `findAll` returns the full `events` table (currently ~2K rows...); at 1M rows this handler will time out" is a finding; "this could be slow" is not.

1. **Database access.** N+1 queries (a query inside a loop over results — the classic killer), missing indexes on filtered/joined columns, unbounded `SELECT *`/`findAll` with no pagination.
2. **Algorithmic complexity.** Nested loops over data that scales with user/tenant count, an O(n²) operation on a collection with no practical size ceiling.
3. **Memory / leaks.** Unbounded caches/collections that grow with request count, listeners/subscriptions never unregistered, large payloads held in memory longer than needed.
4. **Concurrency / blocking.** Synchronous I/O on a hot path meant to be async, a lock held across an I/O call, a shared mutable structure accessed without synchronization.
5. **Network / IO.** Serial requests that could be parallelized, no timeout on an external call, repeated re-fetching of unchanged data.
6. **Caching.** Missing cache on an expensive, frequently-repeated computation; a cache with no invalidation strategy (stale-forever) or no TTL.
7. **Frontend / payload.** Oversized API responses (unneeded fields), missing pagination/virtualization on a large list render, render-blocking synchronous work on the main thread.

Closing rule: **demand a number.** "This handler will time out at scale" needs a stated current size and a stated breaking point, not just "this is inefficient."
