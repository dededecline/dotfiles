# Global Codex Instructions

These instructions apply to all repositories.

## Writing Style

**Never use em dashes (—) under any circumstances.** This applies to
everything: chat responses, commit messages, PR descriptions, code
comments, documentation, file contents, and any other output. There are
no exceptions, including when quoting, paraphrasing, or matching an
existing style that uses them.

Use one of these instead:
- A period for a hard break between thoughts
- A comma for a soft pause or aside
- Parentheses for a parenthetical
- A colon for an introduction or expansion
- A semicolon for closely related independent clauses

Also avoid en dashes (–) in prose; use a hyphen (-) for ranges only when
unavoidable.

## Git Identity

Never add `Co-Authored-By` trailers to commits. Never use `--author`
overrides. All commits must use the user's own git identity exclusively.

## Git Workflow for Work (pinginc) Repos

Work repos are any repo with a `pinginc` remote. In these repos:

### Commit Messages

Use conventional commit format with a Linear ticket ID:

  type: LINEAR-ID: description

Valid types: `feat`, `fix`, `chore`, `docs`, `test`, `refactor`, `ci`,
`build`, `perf`, `style`, `revert`

Examples:

  feat: ENG-123: add user authentication
  fix: PLAT-456: resolve race condition in queue consumer
  chore: ENG-789: update CI workflow to use Node 20

### Branch Workflow

Never push directly to `main` or `master`. Always create a feature branch
and open a pull request.

## Pull Requests (All Repos)

- Keep PR titles short (under 70 characters) and descriptive
- Use the body for details with Summary (bullet points) and Test Plan sections
- Do not include AI attribution in PR titles or body
