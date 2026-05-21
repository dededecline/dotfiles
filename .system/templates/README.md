# Secret Templates

This directory contains template files with 1Password references.
The `.system/setup/secrets.sh` script uses `op inject` to populate these templates
with actual values from 1Password.

## Required 1Password Items

Create these items in your 1Password vault:

### Work 1Password Account (uses `op read`)
- **Vault:** Private
- **Item name:** 1password-work-account
- **Field:** domain (the work 1Password account domain)

This is read dynamically by `secrets.sh` to authenticate against the work 1Password account
for work-specific secrets (e.g., Claude skills, telemetry). Only used on work profile.

To create:
```bash
op item create --category=login --title="1password-work-account" \
  --vault="Private" --account my.1password.com \
  domain="your-work-account.1password.com"
```

### NPM Token (`npmrc.tpl`)
- **Vault:** Private (or your preferred vault)
- **Item name:** npm
- **Field:** credential (contains your npm auth token)

To create:
1. Generate a token at https://www.npmjs.com/settings/tokens
2. Create a new item in 1Password:
   ```
   op item create --category=login --title="npm" --vault="Private" credential="npm_your_token_here"
   ```

### ArgoCD (`argocd-config.tpl`)
- **Vault:** Private (or your preferred vault)
- **Item name:** argocd-akuity
- **Fields:**
  - server (contains your ArgoCD server domain)
  - auth-token (contains your ArgoCD JWT token)

To create:
1. Log in to ArgoCD: `argocd login <your-argocd-server>`
2. Get your auth token from `~/.config/argocd/config`
3. Create a new item in 1Password:
   ```
   op item create --category=login --title="argocd-akuity" --vault="Private" server="your.argocd.server" auth-token="your_jwt_token_here"
   ```

### Atuin Sync (uses `op read`)
- **Vault:** Private
- **Item name:** Atuin
- **Fields:**
  - username (your Atuin account username)
  - password (your Atuin account password)
  - key (encryption key from `~/.local/share/atuin/key`)

To create:
1. Register at https://atuin.sh or your self-hosted instance
2. Copy your encryption key: `cat ~/.local/share/atuin/key`
3. Create a new item in 1Password:
   ```
   op item create --category=login --title="Atuin" --vault="Private" username="your_username" password="your_password" key="your_encryption_key"
   ```

Note: Unlike other secrets, Atuin uses `op read` directly instead of template injection,
since it requires running `atuin login` rather than writing a config file.

### Work CLI (`clone.fish.tpl`)
- **Vault:** Private (or your preferred vault)
- **Item name:** work-cli
- **Fields:**
  - org (contains the GitHub organization name)

To create:
1. Create a new item in 1Password:
   ```
   op item create --category=login --title="work-cli" --vault="Private" org="your-org"
   ```

### Display Monitor (`display-monitor.plist.tpl`)
- **Vault:** Private
- **Item name:** git-identity
- **Field:** name (your username for the home path)

This LaunchAgent monitors display connection changes and automatically reloads
aerospace and sketchybar configurations when displays are connected/disconnected.

The `git-identity` item is already used for git config, so no additional setup needed.
If you don't have it yet:
```bash
op item create --category=login --title="git-identity" --vault="Private" \
  name="your-username" email="your@email.com"
```

The display monitor runs every 3 seconds and logs to `~/.config/logs/display-monitor.log`.

### Spotlight Shortcuts (`spotlight-shortcuts.plist.tpl`)
- **Vault:** Private
- **Item name:** git-identity
- **Field:** name (your username for the home path)

This LaunchAgent runs `.system/setup/disable-spotlight-shortcuts.sh` at login to re-disable
Spotlight keyboard shortcuts (keys 64, 65, 160) that macOS re-enables on every restart.
This prevents conflicts with Raycast's `Option+Space` binding.

The `git-identity` item is already used for git config and display monitor, so no
additional setup needed.

The script waits 10 seconds after login for macOS to finish its boot-time shortcut
restoration, then applies the `defaults write` commands and activates the settings.
Logs to `~/.config/logs/spotlight-shortcuts.log`.

### RustDesk Password (`rustdesk-password.tpl`)
- **Vault:** Private
- **Item name:** RustDesk
- **Field:** password (permanent password for unattended access)

Used on server machines for remote desktop access over Tailscale.

To create:
```bash
op item create --category=login --title="RustDesk" --vault="Private" password="your_secure_password"
```

### Global Claude Instructions (1Password Document)

The contents of `~/.claude/CLAUDE.md` (the global instructions Claude Code
applies to every repo) are stored as a 1Password Document so they can sync
between machines without being committed to the repo.

- **Account:** <Personal> (`my.1password.com`)
- **Vault:** Private
- **Document title:** `claude-global-instructions`

On every `setup.sh` run (including `--brew` and `--macos`), `secrets.sh`
materializes the document to `.system/sensitive/CLAUDE.global.md` (mode
600), and `symlinks.sh` links it into `~/.claude/CLAUDE.md`.

Drift is handled with the same bi-directional `[l/r]` prompt the
claude-skills loop uses: choosing `l` pushes local back via `op document
edit`; choosing `r` overwrites local with the remote copy.

Refresh on demand without a full setup run:
```bash
secrets --claude-global
# or
bash ~/.config/.system/setup/secrets.sh --claude-global
```

### Work-Specific Claude Skills (1Password Documents)

Work-specific Claude Code skills are stored as 1Password documents (not templates)
because the tool names themselves are sensitive. These are retrieved using `op document get`
and placed in `.system/sensitive/claude-skills/`, then symlinked to `claude/skills/`.

**Document names in 1Password Private vault:**
- `claude-skill-argocd` | GitOps deployment tool skill
- `claude-skill-astro` | Airflow management tool skill
- `claude-skill-bastion_zero` | Zero-trust access tool skill
- `claude-skill-lrl-cli` | Database connection tool skill
- `claude-skill-observe` | Observability platform skill
- `claude-skill-spacectl` | Infrastructure-as-code tool skill

To update a skill:
```bash
# Download the current version
op document get "claude-skill-<name>" --output skill.md

# Edit the file
vim skill.md

# Upload the updated version
op document edit "claude-skill-<name>" skill.md

# Re-run secrets to update local copy
secrets
```

These skills are only installed on work machines (hostname: hera).
Personal machines will not have these skills available.

## Adding New Secrets

1. Create a new `.tpl` file in this directory
2. Use `{{ op://Vault/Item/Field }}` syntax for secret references
3. Add injection logic to `.system/setup/secrets.sh`
4. Update this README with setup instructions

### Adding New Claude Skills (Work-Specific)

For work-specific Claude skills:
1. Create the SKILL.md file locally
2. Upload to 1Password: `op document create SKILL.md --title "claude-skill-<name>" --vault "Private"`
3. Add the skill name mapping to `inject_claude_skills()` in `.system/setup/secrets.sh`
4. Add the skill to `.gitignore` under work-specific Claude skills

## Usage

```bash
# Inject all secrets from 1Password
~/.config/.system/setup/secrets.sh

# Check which secrets are configured
~/.config/.system/setup/secrets.sh --check

# Or use the fish function
secrets        # inject secrets
secrets check  # check status
```
