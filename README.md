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
./setup.sh                      # Run full setup (auto-detects profile from hostname)
./setup.sh --profile personal   # Override profile (work or personal)
./setup.sh --brew               # Sync Homebrew packages only
./setup.sh --macos              # Apply macOS preferences only
./setup.sh --help               # Show all options
```

The setup script is fully idempotent - run it anytime to ensure everything is configured correctly.

## Multi-Machine Support

The setup supports multiple machines with profile-based configuration:

| Hostname | Profile | Description |
|----------|---------|-------------|
| hera | work | Work laptop - includes all work tools and secrets |
| athena | personal | Personal laptop - skips work-specific items |

Profile is auto-detected from hostname. Override with `--profile <work|personal>`.

### Profile-Specific Packages

Use markers in `Brewfile` to install packages only on specific profiles:

```ruby
# @profile:work
cask "linear-linear"        # Work-only
# @end:work

# @profile:personal
cask "some-personal-app"    # Personal-only
# @end:personal
```

### Work-Only Items (skipped on personal profile)

- **Brewfile packages**: Apps marked with `# @profile:work` markers
- **Secrets**: ZLI, CI identity, Brewfile.work, clone function
- **1Password integration**: Skipped entirely on personal profile

## Structure

```
~/.config/
├── setup.sh                 # Main setup script (idempotent)
├── Brewfile                 # Homebrew packages
├── .macos                   # macOS system preferences
├── setup/
│   ├── symlinks.sh          # Symlink creation
│   ├── secrets.sh           # 1Password secrets injection
│   ├── ssh.sh               # SSH key generation
│   ├── monitor-watcher.sh   # Display monitor detection
│   ├── reload-display-config.sh  # Reload aerospace/sketchybar on display change
│   └── lib/
│       ├── output.sh        # Shared output utilities
│       └── profiles.sh      # Multi-machine profile mapping
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

### Work Tools (work profile only)

Work-specific items are only installed on the work profile:

1. **Brewfile packages** in `templates/Brewfile.tpl` (injected via 1Password)
2. **Profile-marked packages** in main `Brewfile` (between `# @profile:work` markers)
3. **Work secrets**: ZLI, CI identity, clone function

On personal profile, these are skipped automatically.

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

Homebrew packages are managed declaratively through `Brewfile`:

```bash
./setup.sh --brew    # Sync Homebrew packages (declarative with --cleanup)
```

### Features

- **Declarative sync**: Installs packages from Brewfile and removes unlisted packages
- **Profile-specific packages**: Uses `@profile:work` and `@profile:personal` markers
- **Automatic tap cleanup**: Removes broken taps (deleted remotes) and undeclared taps
- **Work package injection**: Combines `Brewfile` with `templates/Brewfile.tpl` (work profile only)

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

