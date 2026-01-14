# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a macOS dotfiles repository managed as a git repo in `~/.config`. It uses Fish shell as the primary shell with Starship prompt and Catppuccin Frappe theming throughout.

## Key Commands

### Setup & Bootstrap
```bash
# Fresh machine (one-liner)
curl -fsSL https://raw.githubusercontent.com/dededecline/dotfiles/main/setup.sh | bash

# Local setup
./setup.sh              # Run full setup (idempotent)
./setup.sh --brew       # Sync Homebrew packages only (declarative with --cleanup)
./setup.sh --macos      # Apply macOS system preferences only
```

### Secrets Management (1Password)
```bash
secrets                         # Inject all secrets from 1Password
secrets check                   # Check which secrets are configured
~/.config/setup/secrets.sh --check  # Same as above (bash)
```

### Symlinks Only
```bash
source ~/.config/setup/symlinks.sh  # Just create symlinks
```

### Fish Shell
```bash
reload                          # Reload fish config
fishconfig                      # Edit fish config in nvim
```

## Architecture

### Setup Script

The `setup.sh` script is fully idempotent - run it anytime to ensure everything is configured:
- Installs Xcode CLT and Homebrew (if missing)
- Clones dotfiles repository (if missing)
- Injects secrets from 1Password (if authenticated)
- Syncs Homebrew packages (declarative with --cleanup)
- Creates symlinks
- Configures Fish shell as default
- Installs Fisher, TPM, and aerospace-swipe
- Applies macOS system preferences

Use `--brew` or `--macos` flags to run only those specific tasks.

### macOS Preferences

The `.macos` script sets system defaults via `defaults write` commands:
- **UI**: Dark mode, auto-hide menu bar, expanded save panels
- **Input**: Key repeat enabled, smart punctuation disabled, auto-correct disabled
- **Finder**: POSIX path in title, hidden files visible, no desktop icons
- **Screenshots**: PNG format, no shadow, saves to clipboard
- **Sound**: System beep disabled
- **Trackpad**: Tap to click disabled
- **Security**: Touch ID for sudo authentication

Run standalone with `./setup.sh --macos`.

### Homebrew Management

Homebrew packages are managed declaratively with `brew bundle --cleanup`:
- Base packages defined in `Brewfile`
- Work packages in `templates/Brewfile.tpl` (injected via 1Password to `sensitive/Brewfile.work`)
- Combined at runtime before running `brew bundle`
- `--cleanup` flag removes packages not in the combined Brewfile

### Secrets System

The secrets system uses 1Password CLI (`op inject`) to populate sensitive values:
1. **Templates** (`templates/*.tpl`) - Files with `{{ op://Vault/Item/Field }}` references
2. **secrets.sh** - Processes templates and writes to `sensitive/` directory
3. **sensitive/** - Gitignored directory containing injected credentials

To add a new secret:
1. Create a template in `templates/` with `op://` references
2. Add injection logic to `setup/secrets.sh`
3. Document the required 1Password item in `templates/README.md`

### Symlinks

Traditional dotfiles that expect `~/.<file>` are symlinked:
- `git/config` → `~/.gitconfig`
- `sensitive/.npmrc` → `~/.npmrc`

### Fish Functions

Custom functions in `fish/functions/`:
- `secrets` - Wrapper for secrets.sh
- `gitdone` - Switch to default branch and pull
- `clone` - Clone work repos with archive detection
- `empty` - Create empty commit with CI identity for triggering pipelines
- `z` - Zoxide wrapper for directory jumping
- `awsall` - Run AWS CLI command across all profiles

### Key Aliases

Modern CLI replacements (in `fish/conf.d/aliases.fish`):
- `ls` → lsd, `cat` → bat, `find` → fd, `diff` → difft, `top` → btop
- `k` → kubectl, `tf` → tofu, `vim` → nvim
- `dotfiles` - cd to ~/.config
- `reload` - reload fish config

### Local Overrides

Untracked files for machine-specific config:
- `~/.config/fish/config.local.fish`
