# Secret Templates

This directory contains template files with 1Password references. The
`.system/setup/secrets.sh` script uses `op inject` to populate these templates
with actual values from 1Password.

## Adding New Secrets

1. Create a new `.tpl` file in this directory
2. Use `{{ op://Vault/Item/Field }}` syntax for secret references
3. Add injection logic to `.system/setup/secrets.sh`
4. Update this README with setup instructions

## Full inventory

Every 1Password item this repo reads. Injection is gated by machine group, so a
machine outside the listed group never fetches the item.

| 1Password reference | Group | Produces |
|---|---|---|
| `op://Private/npm-local/credential` | all | `.system/sensitive/.npmrc` |
| `op://Private/GitHub PAT/credential` | all | `.system/sensitive/github-pat` |
| `op://Private/git-identity/{email,username}` | all | `git/config` |
| `op://Private/Atuin/{username,password,key}` | all | `atuin login` (no file) |
| document `claude-global-instructions` | all | `.system/sensitive/CLAUDE.global.md` |
| `op://Private/ci-identity/{name,email}` | work | `.system/sensitive/ci-identity` |
| `op://Private/work-cli/org` | work | `fish/functions/clone.fish` |
| `op://Private/1password-work-account/domain` | work | `$OP_WORK_ACCOUNT` (in memory) |
| `op://Employee/spacelift-api-key/{endpoint,api_key_id,api_key_secret}` | work | 3 artifacts, see below |
| `op://Private/context7/credential` | work | `.system/sensitive/context7-api-key` |
| document `aws-config` | work | `~/.aws/config` |
| document `claude-skill-*` (9 of them) | work | `.system/sensitive/claude-skills/*/` |
| document `claude-rule-pr-lint` | work | `.system/sensitive/claude-rules/pr-lint.md` |
| `op://Engineering Account Credentials/aitooling.weave/credential` | work | `managed-settings.json` (OTEL) |
| `op://Private/RustDesk/password` | server | `.system/sensitive/rustdesk-password` |
| `op://Private/anthropic-claude-api/password` | server | `.system/sensitive/anthropic-api-key` |
| `op://Private/Tailscale Server/{tailnet,credential}` | server | 2 files, see below |

Two credentials are deliberately **not** here:

- `.system/sensitive/warpstream.fish` is a static file with no template and no
  `secrets.sh` entry, rotated by editing in place, so WarpStream auth never
  depends on 1Password at runtime. `secrets --check` verifies its three keys are
  present. See `CLAUDE.md`.
- `~/.observe/config.json` is owned by `observe auth configure`, the single write
  path. `secrets --check` reports it but never writes it.

### npm Token

`npmrc.tpl` injects the npm registry auth token into `.system/sensitive/.npmrc`
(symlinked to `~/.npmrc`). It reads `op://Private/npm-local/credential`, so the
item **named `npm-local`** in the Private vault must have a field named
`credential` holding an npm access token (create one at npmjs.com > Access
Tokens, or `npm token create`). The token was previously stored in the macOS
Keychain, which does not survive a machine reset; 1Password does.

Note `fish/config.fish` still reads `NPM_TOKEN` from the Keychain via
`security find-generic-password`. That path is dead, so `NPM_TOKEN` is normally
unset while `~/.npmrc` holds the real token.

### AWS Config (work machines only)

`inject_aws_config()` materializes `~/.aws/config` from a 1Password **document**
titled `aws-config` in the work account. There is no `.tpl`: the file is
hand-maintained, and its comment header (the profile safety model, the `laurel`
session-name constraint, which roles are escalation-gated) is the point. A
per-account `op://` template would strip exactly that.

Drift is handled bidirectionally like `claude-global-instructions`: on a diff you
get `[l]ocal` / `[r]emote`, and anything else keeps local and pushes nothing.

To seed it the first time, when the local file is the only copy:

    op document create ~/.aws/config --title aws-config --account "$OP_WORK_ACCOUNT"

It holds 5 AWS account ids, which is why it lives in 1Password rather than in
this public repo.

### Context7 API Key (work machines only)

`context7-api-key.tpl` reads `op://Private/context7/credential` into
`.system/sensitive/context7-api-key`. The key is read at MCP connection time by
`.system/mcp/context7-header.sh`, never placed on a command line or in an
environment variable. Get a key from context7.com; it starts with `ctx7sk`.

### Tailscale Server Identity (server machines only)

`tailscale-tailnet.tpl` and `tailscale-authkey.tpl` inject the tailnet nyx should
belong to and the credential used to (re)authenticate it. Both read from a
`Tailscale Server` item in the Private vault, which needs two fields:

- `tailnet` — the tailnet name as shown in the `Tailnet` column of
  `tailscale switch --list`, which is what `tailscale status --json` reports as
  `.CurrentTailnet.Name`. It lives in 1Password rather than a repo constant
  because this repo is public and the name is a private domain.

  **Not the tailnet DNS name.** A tailnet has two names: the tailnet name (an org
  identifier, shown in the admin console sidebar) and the tailnet DNS name (the
  MagicDNS suffix, `something.ts.net`, shown on the DNS page). The health check
  compares against the former. Putting the `.ts.net` suffix here makes every
  cutover fail its tailnet-name check and roll back.
- `credential` — an **OAuth client secret**, not an auth key. Create it in the
  tailnet's admin console under Settings > Trust credentials > + Credential:
  type OAuth, scope Keys > Auth Keys > **Write**, and the server's tag attached
  (the Tags field is required for write scope, and only tags already present in
  `tagOwners` are selectable). OAuth secrets do not expire; auth keys cap out at
  90 days, which would break idempotent re-auth. Note the description field
  accepts alphanumerics and spaces only.

The credential's **client ID** is not used by anything here: the CLI takes the
secret alone, and the ID is embedded in it (`tskey-client-<clientID>-<secret>`).
Worth pasting into the item's `username` field anyway, since the admin console
lists trust credentials by client ID and that is how you identify which one to
revoke or rotate.

The secret is always used with `?ephemeral=false&preauthorized=true` appended.
Nodes registered with an OAuth secret are **ephemeral by default**, and an
ephemeral server would be deleted from the tailnet every time it disconnects.

The tailnet's policy must also grant the tagged server access.
`.system/setup/tailnet-switch.sh --policy` prints what is required. Reusing a tag
that an existing, reachable machine already carries means the existing rules cover
the new machine and no policy edit is needed.

### Spacelift (work machines only)

`spacelift-api-key.tpl` and `spacelift-profile.json.tpl` both read the
`spacelift-api-key` item in the **work** account's `Employee` vault, which needs
three fields: `endpoint` (e.g. `https://<org>.app.spacelift.io`), `api_key_id`
(26-character ULID), and `api_key_secret`.

`inject_spacelift()` turns that one item into the three credentials Spacelift
tooling actually reads, because no single file serves all of them:

| Consumer | Artifact | Why it can't share |
| --- | --- | --- |
| Spacelift Terraform provider | `.system/sensitive/spacelift-api-key.fish` | Reads `SPACELIFT_API_KEY_*` env vars and nothing else |
| `spacectl` CLI / GraphQL API | `~/.spacelift/config.json` | Works outside fish (GUI apps, LaunchAgents), where env vars never reach |
| OpenTofu module registry | `~/.terraform.d/credentials.tfrc.json` | Reads only OpenTofu's own credentials files |

The two files outside this repo are written directly to `$HOME` and are
therefore outside any git worktree. Nothing here holds a credential in the repo:
the templates carry `op://` references only.

The registry token is `base64("api:${api_key_id}:${api_key_secret}")` **with the
padding stripped**, computed in `inject_spacelift()` rather than templated
because `op inject` substitutes values but cannot transform them. It does not
expire — it is the API key, encoded.

The API key must have read access to the relevant spaces, and if login policies
exist, a non-admin key needs an explicit policy allowing it.

**Never run `tofu login spacelift.io`.** It replaces the permanent registry
token with a browser-issued SSO JWT that expires in 10 hours, which is the
`401 Unauthorized ... error looking up module versions` failure mode. Re-run
`secrets --spacelift` (aliased to `spacelogin`) to repair or rotate.

### Adding New Claude Skills (Work-Specific)

Work documents live in the **`Employee` vault on the work account**, not in
`Private`. Resolve the account rather than typing the domain, which is itself a
secret:

    work=$(op read "op://Private/1password-work-account/domain" --account my.1password.com)

1. Create the SKILL.md file locally
2. Upload to 1Password:
   `op document create SKILL.md --title "claude-skill-<name>" --vault Employee --account "$work"`
3. Add the `<name>:claude-skill-<name>` pair to `inject_claude_skills()` in
   `.system/setup/secrets.sh`, and to the `work_skills` array in
   `check_secrets()`
4. Add `skills/<name>` to `claude/.gitignore` under the work-specific block, so
   the symlinked copy is never committed

### Adding New Claude Rules (Work-Specific)

Rules load as global instructions in every session, so put one in 1Password only
when its content is genuinely work-specific. A rule that must always apply
belongs in the repo, sanitized, because a 1Password-backed rule does not exist
until `secrets` has run and nothing reports it missing.

1. Write the rule locally at `.system/sensitive/claude-rules/<name>.md`
2. Upload it:
   `op document create .system/sensitive/claude-rules/<name>.md --title "claude-rule-<name>" --vault Employee --account "$work"`
3. Add the `<name>:claude-rule-<name>` pair to `work_rules` in
   `inject_claude_rules()`, and to the `work_rules` array in `check_secrets()`
4. Nothing to add to `claude/.gitignore`: it ignores `rules/*` and allowlists
   only the generic rules by name, so a new rule is hidden by default

`symlinks.sh` links every `.md` in that directory into `claude/rules/`, so no
per-rule wiring is needed there.

## Usage

```bash
# Inject all secrets from 1Password
~/.config/.system/setup/secrets.sh

# Check which secrets are configured
~/.config/.system/setup/secrets.sh --check

# Refresh a single credential group
~/.config/.system/setup/secrets.sh --spacelift

# Or use the fish function
secrets        # inject secrets
secrets check  # check status
```
