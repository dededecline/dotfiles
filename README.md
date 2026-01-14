# Dededecline's Dotfiles

Personal dotfiles managed as a git repository in `~/.config`.

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

### Work Tools

Work-specific Homebrew packages are defined in `templates/Brewfile.tpl`. When authenticated with 1Password, these are automatically included in `./setup.sh --brew`.

## Symlinks

Files that expect `~/.<file>` locations are symlinked:

| Source | Target |
|--------|--------|
| `~/.config/git/config` | `~/.gitconfig` |
| `~/.config/sensitive/.npmrc` | `~/.npmrc` |

## macOS Preferences

The `.macos` script configures system preferences via `defaults write`.

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
