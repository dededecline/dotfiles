# Inline code comments

Do not write comments in code files. Default to none.

A comment is justified only when it carries context that cannot be derived
from the code file itself **and** cannot be derived from any other
documentation (README, CLAUDE.md, ADR, ticket, PR description, commit
message). If the information lives anywhere else, or could, it belongs there
instead.

Before writing a comment, confirm all three:

1. A competent reader of this file cannot recover the information by reading
   the surrounding code.
2. No documentation file already carries it, and none is the better home.
3. Getting it wrong would cause a future reader to break something.

If any check fails, delete the comment. A clearer name, a smaller function,
or a more obvious structure beats a comment every time.

## The narrow set that survives

- **Non-obvious constraints:** workarounds, ordering requirements, surprising
  invariants, performance hacks, regex intent. Anything a future reader might
  "fix" incorrectly. Link the issue or PR where one exists.
- **Boundary assumptions on public APIs:** preconditions, input shape,
  ownership. Belongs in a docstring, not an inline note.
- **Searchable markers:** `TODO`, `FIXME`, `HACK`, `WARNING`, with enough
  context to act on later.

## Never

- Restating what the next line does in English.
- Section headers or banners that decorate structure the code already shows.
- Excuse comments papering over unclear code. Refactor instead.
- Commented-out code. Use version control.
- Task-local context ("added for X flow", "used by Y", "per review feedback").
  That belongs in the PR description and rots in source.
- Attribution or change narration ("updated to...", "new in...").

## Style when one is justified

One line is the target, two is the ceiling. Needing a paragraph means the code
needs restructuring. Put it on its own line above the code, never trailing.
State the why, never the what.

Treat a stale comment as a bug: delete or fix it alongside the code it
describes.

## Applies to

Every code file, in every language, including config formats that permit
comments (`.jsonc`, `.toml`, `.yaml`, Dockerfiles, shell). It does not apply to
documentation files, whose whole purpose is prose.

One exception, because the alternative is a broken file rather than an untidy
one: `claude/settings.jsonc` may carry `@machine:` / `@end:` marker comments,
which `setup.sh` strips during generation. Any other `//` line there survives
preprocessing and breaks `jq`.
