# Dededecline's Dotfiles

Personal dotfiles managed as a git repository in `~/.config`.

![Kitty Terminal](assets/terminal.jpg)
![Empty Screen](assets/empty-screen.jpg)

## Quick Start

### Fresh Install (New Machine)

```bash
# One-liner (installs Xcode CLT and Homebrew if needed)
curl -fsSL https://raw.githubusercontent.com/dededecline/dotfiles/main/setup.sh | bash
```

### Existing Installation

```bash
./setup.sh                      # Run full setup (auto-detects from hostname)
./setup.sh --hostname athena    # Override hostname
./setup.sh --brew               # Sync Homebrew packages only
./setup.sh --macos              # Apply macOS preferences only
./setup.sh --help               # Show all options
```

The setup script is fully idempotent - run it anytime to ensure everything is configured correctly.

## Multi-Machine Support

The setup supports multiple machines with hostname-based configuration:

| Hostname | Type | Brew Groups |
|----------|------|-------------|
| hera | Work laptop | all + laptops + infra + hera |
| athena | Personal laptop | all + laptops + personal + athena |
| nyx | Personal server | all + personal + infra + nyx |

Hostname is auto-detected. Override with `--hostname <name>`.

### Machine-Specific Packages

Packages are organized under `profiles/`:

```
profiles/
├── shared/
│   ├── all/
│   │   ├── Brewfile         # All machines
│   │   └── hostnames        # Lists all hostnames in this group
│   ├── laptops/
│   │   ├── Brewfile         # hera + athena
│   │   └── hostnames
│   ├── personal/
│   │   ├── Brewfile         # athena + nyx
│   │   └── hostnames
│   └── infra/
│       ├── Brewfile         # hera + nyx
│       └── hostnames
└── individual/
    ├── hera/Brewfile        # hera only
    ├── athena/Brewfile      # athena only
    └── nyx/Brewfile         # nyx only
```

### Hera-Specific Items

- **Work Brewfile**: `templates/Brewfile.tpl` injected via 1Password to `sensitive/Brewfile.work`
- **Work secrets**: ZLI, CI identity, clone function, Claude skills
- **1Password work integration**: Only on hera

## Structure

```
~/.config/
├── setup.sh                 # Main setup script (idempotent)
├── profiles/                # Machine profiles (shared + individual Brewfiles + hostnames)
├── .macos                   # macOS system preferences
├── setup/
│   ├── symlinks.sh          # Symlink creation
│   ├── secrets.sh           # 1Password secrets injection
│   ├── ssh.sh               # SSH key generation
│   ├── monitor-watcher.sh   # Display monitor detection
│   ├── reload-display-config.sh  # Reload aerospace/sketchybar on display change
│   └── lib/
│       ├── output.sh        # Shared output utilities
│       └── profiles.sh      # Multi-machine hostname utilities
├── templates/               # 1Password template files (op:// refs)
├── sensitive/               # Injected secrets (gitignored)
├── fish/
│   ├── config.fish          # Main config
│   ├── conf.d/
│   │   ├── path.fish        # PATH configuration
│   │   └── aliases.fish     # Aliases & abbreviations
│   └── functions/           # Custom functions
├── aerospace/               # AeroSpace window manager
├── sketchybar/              # SketchyBar status bar
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

### Work Tools (hera only)

Work-specific items are only installed on hera:

1. **Brewfile packages** in `templates/Brewfile.tpl` (injected via 1Password)
2. **Work secrets**: ZLI, CI identity, clone function, Claude skills

On other machines, these are skipped automatically.

## Process Management

Reload configured processes after making config changes:

```bash
refresh                  # Reload all configured processes (fish, aerospace, sketchybar, tmux)
refresh fish             # Reload Fish shell config only
refresh aerospace        # Reload Aerospace window manager only
refresh sketchybar       # Reload Sketchybar status bar only
refresh tmux             # Reload Tmux config only (if in tmux session)
```

The `refresh` command is useful after editing dotfiles to apply changes immediately without restarting applications.

## Homebrew Management

Homebrew packages are managed declaratively through `profiles/`:

```bash
./setup.sh --brew    # Sync Homebrew packages (declarative with --cleanup)
```

### Features

- **Declarative sync**: Combines shared + individual Brewfiles per machine, removes unlisted packages
- **Group-based composition**: Each machine maps to brew groups via `profiles/shared/*/hostnames` files
- **Automatic tap cleanup**: Removes broken taps (deleted remotes) and undeclared taps
- **Work package injection**: Appends `sensitive/Brewfile.work` on hera (from 1Password)

The script automatically:
1. Detects and removes broken taps (with deleted/missing remotes)
2. Removes taps not declared in Brewfile
3. Updates Homebrew
4. Syncs packages with `brew bundle --cleanup`

This prevents errors like "fatal: couldn't find remote ref" when taps are manually added or left behind after packages are removed.

## macOS Preferences

The `.macos` script configures system preferences via `defaults write`:

- **UI**: Dark mode, auto-hide menu bar, expanded save panels
- **Input**: Key repeat enabled, smart punctuation disabled, auto-correct disabled
- **Finder**: POSIX path in title, hidden files visible, no desktop icons
- **Screenshots**: PNG format, no shadow, saves to clipboard
- **Sound**: System beep disabled
- **Trackpad**: Tap to click disabled
- **Raycast**: Disables conflicting Spotlight, Input Sources, and Siri keyboard shortcuts
- **Security**: Touch ID for sudo authentication

Run standalone with `./setup.sh --macos`. Some changes require logout/restart.

## Customization

### Local Overrides

Create these files for machine-specific config (not tracked in git):

- `~/.config/fish/config.local.fish` - Local fish configuration

