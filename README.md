# Dotfiles

Personal dotfiles managed as a git repository in `~/.config`.

Modeled after [driesvints/dotfiles](https://github.com/driesvints/dotfiles).

## Table of Contents

- [Quick Start](#quick-start)
- [What Gets Installed](#what-gets-installed)
- [Structure](#structure)
- [Shell Configuration](#shell-configuration)
- [Secrets Management](#secrets-management)
- [macOS Preferences](#macos-preferences)
- [Manual Steps](#manual-steps)
- [Customization](#customization)

## Quick Start

### Fresh Install (New Machine)

```bash
# One-liner (installs Xcode CLT and Homebrew if needed)
curl -fsSL https://raw.githubusercontent.com/dededecline/dotfiles/main/setup.sh | bash
```

### Existing Installation

```bash
./setup.sh              # Run full setup (idempotent)
./setup.sh --brew       # Sync Homebrew packages only
./setup.sh --macos      # Apply macOS preferences only
./setup.sh --help       # Show all options
```

The setup script is fully idempotent - run it anytime to ensure everything is configured correctly.

## What Gets Installed

### Core Tools

| Tool | Replaces | Description |
|------|----------|-------------|
| **fish** | bash/zsh | Primary shell |
| **starship** | p10k | Cross-shell prompt |
| **neovim** | vim | Editor |
| **tmux** | - | Terminal multiplexer |
| **kitty** | Terminal.app | GPU-accelerated terminal |

### Modern CLI Replacements

| Tool | Replaces | Description |
|------|----------|-------------|
| **bat** | cat | Syntax highlighting |
| **lsd** | ls | Icons and colors |
| **fd** | find | Faster file finding |
| **ripgrep** | grep | Faster search |
| **difftastic** | diff | Structural diff |
| **dust** | du | Disk usage visualizer |
| **btop** | top/htop | Resource monitor |
| **gping** | ping | Graph ping |
| **atuin** | history | Shell history with sync |
| **fzf** | - | Fuzzy finder |

### DevOps Tools

- **kubectl**, **helm** - Kubernetes
- **opentofu**, **terraform-docs**, **tflint** - Infrastructure as Code
- **awscli** - AWS
- **trivy**, **pluto** - Security and deprecation scanning

### Window Management

- **AeroSpace** - Tiling window manager (i3-like)
- **aerospace-swipe** - Trackpad gesture integration
- **BetterTouchTool** - Input customization

## Structure

```
~/.config/
├── setup.sh                 # Main setup script (idempotent)
├── Brewfile                 # Homebrew packages
├── .macos                   # macOS system preferences
├── setup/
│   ├── symlinks.sh          # Symlink creation
│   ├── secrets.sh           # 1Password secrets injection
│   └── ssh.sh               # SSH key generation
├── templates/               # 1Password template files (op:// refs)
├── sensitive/               # Injected secrets (gitignored)
├── fish/
│   ├── config.fish          # Main config
│   ├── conf.d/
│   │   ├── path.fish        # PATH configuration
│   │   └── aliases.fish     # Aliases & abbreviations
│   └── functions/           # Custom functions
├── aerospace/               # AeroSpace window manager
├── git/                     # Git configuration
├── starship.toml            # Starship prompt (Catppuccin themed)
├── kitty/                   # Kitty terminal
├── nvim/                    # Neovim
├── tmux/                    # Tmux
├── atuin/                   # Atuin shell history
├── bat/                     # Bat (syntax themes)
├── lsd/                     # LSD (ls replacement)
└── themes/                  # Shared Catppuccin theme files
```

## Shell Configuration

### Fish Shell

Fish is the primary shell with modular configuration:

- **config.fish** - Environment variables, tool integrations (starship, fzf, atuin)
- **conf.d/path.fish** - PATH configuration (Homebrew, Go, Cargo, etc.)
- **conf.d/aliases.fish** - Modern CLI aliases and abbreviations

### Key Aliases

```fish
# Modern replacements (automatic)
ls → lsd          cat → bat         find → fd
diff → difft      top → btop        du → dust

# Abbreviations (expand as you type)
k → kubectl       tf → tofu         vim → nvim
gs → git status   gd → git diff     gp → git push

# Utilities
reload            # Reload fish config
dotfiles          # cd to ~/.config
fishconfig        # Edit fish config in nvim
kctx              # Show current kubectl context
```

### Custom Functions

| Function | Description |
|----------|-------------|
| `secrets` | Inject secrets from 1Password |
| `secrets check` | Check which secrets are configured |
| `gitdone` | Switch to default branch and pull |
| `clone <repo>` | Clone work repos with archive detection |
| `empty` | Create empty commit with CI identity (for triggering pipelines) |
| `z <dir>` | Zoxide directory jumping |
| `awsall <cmd>` | Run AWS CLI command across all regions |

### Starship Prompt

Two-line prompt with Catppuccin Frappe theme showing:
- Directory (truncated to repo root)
- Git branch and status
- Command duration (if > 2s)
- Kubernetes context (in k8s directories)
- Terraform workspace (in tf directories)
- AWS profile/region
- Time

## Secrets Management

Secrets are managed using 1Password CLI with template injection:

```bash
secrets                  # Inject all secrets from 1Password
secrets check            # Check which secrets are configured
```

### Template System

1. **Templates** (`templates/*.tpl`) contain `{{ op://Vault/Item/Field }}` references
2. **secrets.sh** processes templates via `op inject`
3. **Output** goes to `sensitive/` (gitignored)

### Managed Secrets

| Secret | Purpose |
|--------|---------|
| Git identity | Name and email for commits |
| CI identity | Bot identity for `empty` function |
| Work Brewfile | Work-specific Homebrew packages |
| Clone function | Work GitHub org configuration |
| Atuin sync | Shell history sync credentials |

See [templates/README.md](templates/README.md) for 1Password item setup.

### Work Tools

Work-specific Homebrew packages are defined in `templates/Brewfile.tpl`. When authenticated with 1Password, these are automatically included in `./setup.sh --brew`.

## Symlinks

Files that expect `~/.<file>` locations are symlinked:

| Source | Target |
|--------|--------|
| `~/.config/git/config` | `~/.gitconfig` |
| `~/.config/sensitive/.npmrc` | `~/.npmrc` |

## macOS Preferences

The `.macos` script configures system preferences via `defaults write`:

**UI**: Dark mode, auto-hide menu bar, expanded save panels, small sidebar icons

**Input**: Key repeat enabled, smart punctuation disabled, auto-correct disabled

**Finder**: POSIX path in title, hidden files visible, no desktop icons, search current folder

**Screenshots**: PNG format, no shadow, saves to clipboard

**Security**: Touch ID for sudo authentication

**Trackpad**: Tap to click disabled

Run standalone with `./setup.sh --macos`. Some changes require logout/restart.

## Manual Steps

After running `setup.sh`:

1. **Restart terminal** to use Fish shell

2. **Install tmux plugins**: Open tmux and press `prefix + I`

3. **Set up secrets** (if skipped during setup):
   ```bash
   op signin
   secrets
   ```

4. **Sign in to services**:
   ```bash
   gh auth login          # GitHub CLI
   atuin login            # Or run 'secrets' if credentials in 1Password
   ```

## Customization

### Local Overrides

Create these files for machine-specific config (not tracked in git):

- `~/.config/fish/config.local.fish` - Local fish configuration

### Theming

All tools use **Catppuccin Frappe** theme:
- Starship prompt colors defined in `starship.toml`
- FZF colors set in `fish/config.fish`
- Bat theme in `bat/themes/`
- Kitty theme in `kitty/kitty.conf`
