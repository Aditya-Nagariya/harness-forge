# Code quality checklist

7 categories.

1. **Architecture.** A module doing two unrelated jobs, a layering violation (e.g. a data-access concern leaking into a presentation layer), a circular dependency.
2. **Code smells.** Duplicated logic that should be one function, a function doing too many things, deeply nested conditionals that should be early-returns/guard clauses.
3. **Naming.** A name that actively misleads about what the thing does or holds — not a name you'd have picked differently.
4. **Error-handling consistency.** Mixed error-handling idioms in the same module (some paths throw, some return null, some log-and-swallow) with no stated reason.
5. **Docs.** A public API with no doc comment explaining a non-obvious contract (not "every function needs a comment" — only where the WHY or a hidden constraint isn't obvious from the code).
6. **Testability.** A function that's hard to test because it reaches out to a global/singleton/real network call instead of taking its dependencies as parameters.
7. **Tooling.** Lint/format/type-check gates that exist but are being bypassed (a suppression comment with no justification).

## What NOT to flag

Don't bikeshed subjective style the project's own linter/formatter doesn't enforce — a long argument about tabs vs. spaces, or "I'd have named this differently" with no actual cost, has no place in a senior review.
