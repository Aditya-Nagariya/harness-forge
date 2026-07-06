# Safety rules

Human-readable mirror of the hard gates in `.claude/hooks/{protect-files,scan-secrets,block-dangerous-commands}.sh` — read this, but don't rely on the hooks alone; know the rules directly.

- Never `git push --force` (use `--force-with-lease` if truly needed, and confirm with the user first). Also blocked: `git reset --hard`, `git clean -f*`, `chmod 777`/`a+rwx`, `curl|wget` piped to a shell, publishing to a package registry without `--dry-run`.
- Never `rm -rf` anything under the protected directories (see `PROTECTED_DIRS` in `.claude/harness.env`), `.git`, root, home, or an unresolved shell variable.
- Never hand-edit lockfiles — regenerate via the package manager.
- Never write directly to `.claude/hooks/*` via Write/Edit — these enforce the boundaries above; edit them manually outside the agentic loop if they're genuinely wrong.
- Content containing something that looks like a credential triggers a confirm-first prompt, not a silent write.
- Always run the test command before marking a `TASKS.md` item `completed` (see `ship-verification.md` for the fuller bar).
