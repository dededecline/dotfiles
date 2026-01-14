# Secret Templates

This directory contains template files with 1Password references.
The `setup/secrets.sh` script uses `op inject` to populate these templates
with actual values from 1Password.

## Required 1Password Items

Create these items in your 1Password vault:

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

### Atuin Sync (no template - uses `op read`)
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

### Work CLI (`Brewfile.tpl`, `clone.fish.tpl`)
- **Vault:** Private (or your preferred vault)
- **Item name:** work-cli
- **Fields:**
  - org (contains the GitHub organization name)
  - tap (contains the Homebrew tap, e.g., `org/repo`)
  - formula (contains the formula name, e.g., `org/repo/cli`)

To create:
1. Create a new item in 1Password:
   ```
   op item create --category=login --title="work-cli" --vault="Private" org="your-org" tap="org/repo" formula="org/repo/cli"
   ```

### Work Brew Tools (`Brewfile.tpl`)

The following 1Password items store Homebrew tap/formula references for work tools.
Item names are anonymized to avoid revealing specific tooling in the dotfiles repo.

#### Infrastructure CD (`brew-infra-cd`)
```bash
op item create --category=login --title="brew-infra-cd" --vault="Private" \
  tap="<tap>" formula="<formula>"
```

#### Secure Access (`brew-secure-access`)
```bash
op item create --category=login --title="brew-secure-access" --vault="Private" \
  tap="<tap>" formula="<formula>"
```

#### Ephemeral Environments (`brew-ephemeral-env`)
```bash
op item create --category=login --title="brew-ephemeral-env" --vault="Private" \
  tap="<tap>" formula="<formula>"
```

#### Internal Tool (`brew-internal-tool`)
```bash
op item create --category=login --title="brew-internal-tool" --vault="Private" \
  tap="<tap>" formula="<formula>"
```

#### Kubernetes CD (`brew-k8s-cd`)
```bash
op item create --category=login --title="brew-k8s-cd" --vault="Private" \
  formula="<formula>"
```

#### CI Tool (`brew-ci-tool`)
```bash
op item create --category=login --title="brew-ci-tool" --vault="Private" \
  formula="<formula>"
```

#### Database CLI (`brew-db-cli`)
```bash
op item create --category=login --title="brew-db-cli" --vault="Private" \
  formula="<formula>"
```

#### Incident Management (`brew-incident-mgmt`)
```bash
op item create --category=login --title="brew-incident-mgmt" --vault="Private" \
  tap="<tap>" formula="<formula>"
```

### Claude Code Instructions (`config-instructions.tpl`)
- **Vault:** Private
- **Item name:** config-instructions
- **Field:** notesPlain (Secure Note content)

This stores project-specific instructions for Claude Code without committing them publicly.

To create:
1. Create a Secure Note in 1Password named "config-instructions" in Private vault
2. Paste your CLAUDE.md content into the note body
3. Run `secrets` to inject it

## Adding New Secrets

1. Create a new `.tpl` file in this directory
2. Use `{{ op://Vault/Item/Field }}` syntax for secret references
3. Add injection logic to `setup/secrets.sh`
4. Update this README with setup instructions

## Usage

```bash
# Inject all secrets from 1Password
~/.config/setup/secrets.sh

# Check which secrets are configured
~/.config/setup/secrets.sh --check

# Or use the fish function
secrets        # inject secrets
secrets check  # check status
```
