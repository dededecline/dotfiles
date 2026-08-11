---
name: context7-mcp
description: Context7 MCP authentication, credential location, and failure diagnosis. Use when a Context7 tool call fails, returns "Invalid API key", rate-limits, or when the server will not connect. The lookup workflow itself lives in claude/rules/context7.md, which is always loaded; this skill covers only what that rule does not.
---

# Context7 MCP

The **lookup workflow** (when to use Context7, `resolve-library-id` then
`query-docs`, one concept per query) is in `claude/rules/context7.md`, which is
loaded into every session. It is the source of truth. Do not duplicate it here.

This skill covers authentication and failure modes.

## How auth works on this machine

Context7 is registered as an **HTTP** MCP server, not stdio:

| Piece | Location |
|---|---|
| Endpoint | `https://mcp.context7.com/mcp` |
| Credential | `.system/sensitive/context7-api-key` (mode 0600, gitignored) |
| Header helper | `.system/mcp/context7-header.sh`, emits `{"CONTEXT7_API_KEY": "..."}` |
| Provisioned by | `secrets`, from `op://Private/context7/credential` |

Claude Code runs the helper at connection time and retries once on a 401, so a
refreshed key needs no session restart.

This replaced an earlier stdio registration that passed `--api-key` on argv,
where the key was visible to any local user through `ps`. Do not reintroduce
that form. The key must never appear in `.claude.json`, in a command line, or in
an environment variable.

To rotate: update the 1Password item, run `secrets`, and the helper picks up the
new value on the next connection.

## Diagnosing failures

**Check `secrets check` first.** It reports `Context7 API key: configured` or
not, which separates a missing credential from a network or endpoint problem.

### "Invalid API key. Please check your API key."

The key is wrong, empty, or revoked. This arrives as a **successful tool
response containing an error string**, not as a transport error, so it is easy to
misread as a normal empty result. Confirm the file is non-empty and that the
value starts with `ctx7sk`, then re-run `secrets`.

### A trap worth knowing

The MCP `initialize` method returns **HTTP 200 with a full capabilities
response for any key at all**, including a made-up one. Only an actual
`tools/call` validates the credential. So never conclude "authenticated" from a
successful connection or a 200 status; make a real query.

This is the same shape as the Spacelift registry check documented in
`CLAUDE.md`, where an unauthenticated request returns 200 with an empty
`versions` array. When probing any credentialed endpoint by hand, assert on the
**content** you expect, not the status code.

### Server will not connect

Verify the helper is executable and produces a well-formed header. **Do not run
it bare**: its only stdout is the live key, so an unpiped run puts the
credential into your scrollback and into the session transcript. Assert on the
shape instead:

```bash
.system/mcp/context7-header.sh | jq -e 'has("CONTEXT7_API_KEY") and (.CONTEXT7_API_KEY | length > 0)'
```

Exit 0 means the helper works. Any stderr with a non-zero exit means the
credential file is missing or unreadable, and the script's messages name the
fix. `.system/mcp/warpstream-header.sh` has the same property; check it the same
way against `."warpstream-api-key"`.

### Rate limiting

Context7 rate-limits per key. Symptoms are throttling messages rather than auth
errors. The mitigation is fewer, better-scoped queries, which the rule already
requires: resolve the library ID once, then one `query-docs` call per distinct
concept, and no more than three calls per question.
