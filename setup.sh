#!/usr/bin/env bash
#
# setup.sh - Unified dotfiles setup script (idempotent)
#
# Usage:
#   ./setup.sh                      # Run full setup (auto-detect profile from hostname)
#   ./setup.sh --profile work       # Override profile (work or personal)
#   ./setup.sh --brew               # Sync Homebrew packages only
#   ./setup.sh --macos              # Apply macOS preferences only
#   ./setup.sh --help               # Show usage
#
# Supported machines:
#   hera   -> work profile (includes work tools and secrets)
#   athena -> personal profile (skips work-specific items)
#
# For fresh installs from a new machine:
#   curl -fsSL https://raw.githubusercontent.com/dededecline/dotfiles/main/setup.sh | bash
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

DOTFILES="${DOTFILES:-$HOME/.config}"

# Auto-detect repo URL from git remote (for forks), fallback to original for fresh installs
get_repo_url() {
    if [[ -d "$DOTFILES/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$DOTFILES" remote get-url origin 2>/dev/null || true)
        if [[ -n "$remote_url" ]]; then
            echo "$remote_url"
            return
        fi
    fi
    echo "https://github.com/dededecline/dotfiles.git"
}

REPO_URL=$(get_repo_url)

# Source output utilities (compact fallback for curl installs where lib doesn't exist yet)
if [[ -f "$DOTFILES/setup/lib/output.sh" ]]; then
    source "$DOTFILES/setup/lib/output.sh"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    print_header() { echo -e "\n${BLUE}===========================================================${NC}\n${BLUE}  $1${NC}\n${BLUE}===========================================================${NC}\n"; }
    print_status() { echo -e "${GREEN}✓${NC} $1"; }
    print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
    print_error() { echo -e "${RED}✗${NC} $1"; }
    print_info() { echo -e "  $1"; }
fi

# Source profile utilities (with fallback for fresh installs)
if [[ -f "$DOTFILES/setup/lib/profiles.sh" ]]; then
    source "$DOTFILES/setup/lib/profiles.sh"
else
    # Minimal fallback for fresh installs - define profile mapping inline
    detect_profile() {
        local hostname="${1:-$(hostname -s)}"
        case "$hostname" in
            hera)   echo "work" ;;
            athena) echo "personal" ;;
            *)      echo "" ;;
        esac
    }
    get_known_hosts() { echo "hera (work), athena (personal)"; }
    is_work_profile() { [[ "${DOTFILES_PROFILE:-}" == "work" ]]; }
    is_personal_profile() { [[ "${DOTFILES_PROFILE:-}" == "personal" ]]; }
fi

# Profile configuration (set by argument parsing or auto-detection)
PROFILE_OVERRIDE=""
DOTFILES_PROFILE=""
MACHINE_HOSTNAME=""

# Detect Homebrew prefix based on architecture
detect_homebrew_prefix() {
    if [[ -d "/opt/homebrew" ]]; then
        echo "/opt/homebrew"  # Apple Silicon
    else
        echo "/usr/local"     # Intel
    fi
}

get_fish_path() {
    echo "$(detect_homebrew_prefix)/bin/fish"
}

# =============================================================================
# Profile Detection
# =============================================================================

# Detect and validate profile from hostname or override
# Sets global DOTFILES_PROFILE and MACHINE_HOSTNAME variables
detect_and_validate_profile() {
    # Determine hostname
    if [[ -n "$PROFILE_OVERRIDE" ]]; then
        # Profile override provided - validate it
        if [[ "$PROFILE_OVERRIDE" != "work" && "$PROFILE_OVERRIDE" != "personal" ]]; then
            print_error "Invalid profile: $PROFILE_OVERRIDE"
            print_info "Valid profiles: work, personal"
            exit 1
        fi
        DOTFILES_PROFILE="$PROFILE_OVERRIDE"
        MACHINE_HOSTNAME=$(hostname -s)
        print_status "Profile: $DOTFILES_PROFILE (overridden, hostname: $MACHINE_HOSTNAME)"
    else
        # Auto-detect from hostname
        MACHINE_HOSTNAME=$(hostname -s)
        DOTFILES_PROFILE=$(detect_profile "$MACHINE_HOSTNAME")

        if [[ -z "$DOTFILES_PROFILE" ]]; then
            print_error "Unknown hostname: $MACHINE_HOSTNAME"
            print_info "Known hosts: $(get_known_hosts)"
            print_info "Override with: ./setup.sh --profile <work|personal>"
            exit 1
        fi
        print_status "Profile: $DOTFILES_PROFILE (detected from hostname: $MACHINE_HOSTNAME)"
    fi

    # Export for child scripts
    export DOTFILES_PROFILE
    export MACHINE_HOSTNAME
}

# Preprocess Brewfile to filter profile-specific packages
# Usage: preprocess_brewfile <input_file> <output_file>
# Markers:
#   # @profile:work ... # @end:work       - work-only packages
#   # @profile:personal ... # @end:personal - personal-only packages
preprocess_brewfile() {
    local input="$1"
    local output="$2"
    local profile="$DOTFILES_PROFILE"

    if [[ "$profile" == "work" ]]; then
        # Work profile: strip personal-only sections, keep work sections
        awk '
            /^# @profile:personal/ { skip=1; next }
            /^# @end:personal/ { skip=0; next }
            !skip { print }
        ' "$input" > "$output"
    else
        # Personal profile: strip work-only sections, keep personal sections
        awk '
            /^# @profile:work/ { skip=1; next }
            /^# @end:work/ { skip=0; next }
            !skip { print }
        ' "$input" > "$output"
    fi
}

# =============================================================================
# Prerequisites
# =============================================================================

ensure_xcode_clt() {
    if xcode-select -p &>/dev/null; then
        print_status "Xcode Command Line Tools: installed"
        return 0
    fi

    print_info "Installing Xcode Command Line Tools..."
    xcode-select --install

    echo ""
    print_warning "Xcode CLT installation started"
    print_info "Please wait for the installation to complete, then run this script again."
    exit 1
}

ensure_homebrew() {
    if command -v brew &>/dev/null; then
        print_status "Homebrew: installed"
        return 0
    fi

    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for this session
    local prefix
    prefix=$(detect_homebrew_prefix)
    eval "$($prefix/bin/brew shellenv)"

    print_status "Homebrew: installed"
}

ensure_dotfiles() {
    if [[ -d "$DOTFILES/.git" ]]; then
        print_status "Dotfiles repository: present"
        return 0
    fi

    print_info "Cloning dotfiles repository..."
    git clone "$REPO_URL" "$DOTFILES"
    print_status "Dotfiles repository: cloned"
}

# =============================================================================
# 1Password Integration
# =============================================================================

ensure_1password_auth() {
    if ! command -v op &>/dev/null; then
        print_warning "1Password CLI not installed - work tools will be skipped"
        return 1
    fi

    if op vault list --account my.1password.com &>/dev/null 2>&1; then
        print_status "1Password: authenticated"
        return 0
    fi

    echo ""
    print_warning "1Password CLI found but not authenticated"

    # Skip prompt in non-interactive mode
    if [[ ! -t 0 ]]; then
        print_info "Non-interactive mode: skipping 1Password sign-in"
        print_info "Run 'op signin' and then 'secrets' later"
        return 1
    fi

    read -p "Sign in to 1Password for work tools and secrets? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Starting 1Password sign-in..."
        if eval "$(op signin 2>/dev/null)"; then
            if op vault list --account my.1password.com &>/dev/null 2>&1; then
                print_status "1Password: authenticated"
                return 0
            fi
        fi
        print_error "Authentication failed"
        print_info "You can run 'secrets' later to set up work tools"
        return 1
    else
        print_info "Skipping 1Password authentication"
        print_info "Run 'secrets' later to set up work tools"
        return 1
    fi
}

inject_secrets() {
    if ! ensure_1password_auth; then
        return 0  # Continue without secrets
    fi

    print_info "Injecting secrets from 1Password..."
    if [[ -x "$DOTFILES/setup/secrets.sh" ]]; then
        "$DOTFILES/setup/secrets.sh"
    else
        bash "$DOTFILES/setup/secrets.sh"
    fi
}

# =============================================================================
# Homebrew Sync (Declarative)
# =============================================================================

prepare_brewfile() {
    local combined="$DOTFILES/.brewfile.combined"
    local preprocessed="$DOTFILES/.brewfile.preprocessed"

    # Preprocess base Brewfile to filter profile-specific packages
    preprocess_brewfile "$DOTFILES/Brewfile" "$preprocessed"

    # Start with preprocessed Brewfile
    cat "$preprocessed" > "$combined"
    rm -f "$preprocessed"

    # Append work Brewfile if it exists (only for work profile)
    if is_work_profile && [[ -f "$DOTFILES/sensitive/Brewfile.work" ]]; then
        echo "" >> "$combined"
        echo "# Work additions (from 1Password)" >> "$combined"
        cat "$DOTFILES/sensitive/Brewfile.work" >> "$combined"
    fi

    echo "$combined"
}

# Check for and remove broken taps (taps with missing/deleted remotes)
# This prevents "fatal: couldn't find remote ref" errors during brew update
check_and_remove_broken_taps() {
    print_info "Checking for broken taps..."

    local broken_taps=()

    # Get list of all taps
    while IFS= read -r tap; do
        [[ -z "$tap" ]] && continue

        # Try to update the tap to see if it's broken
        if ! git -C "$(brew --repository "$tap")" fetch --dry-run origin 2>&1 | grep -q "fatal: couldn't find remote ref"; then
            continue
        fi

        print_warning "Found broken tap: $tap"
        broken_taps+=("$tap")
    done < <(brew tap)

    # Remove broken taps
    if [[ ${#broken_taps[@]} -gt 0 ]]; then
        for tap in "${broken_taps[@]}"; do
            print_info "Removing broken tap: $tap"
            brew untap "$tap" 2>/dev/null || true
        done
        print_status "Removed ${#broken_taps[@]} broken tap(s)"
    else
        print_status "No broken taps found"
    fi
}

# Remove taps not declared in Brewfile
# This cleans up manually added taps that are no longer needed
cleanup_undeclared_taps() {
    local brewfile="$1"

    if [[ ! -f "$brewfile" ]]; then
        return 0
    fi

    print_info "Checking for undeclared taps..."

    # Extract taps from Brewfile
    local declared_taps=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^tap[[:space:]]+\"([^\"]+)\" ]]; then
            declared_taps+=("${BASH_REMATCH[1]}")
        fi
    done < "$brewfile"

    # Check installed taps against declared taps
    local removed_count=0
    while IFS= read -r installed_tap; do
        [[ -z "$installed_tap" ]] && continue

        # Skip homebrew core taps
        if [[ "$installed_tap" =~ ^homebrew/(core|cask|bundle)$ ]]; then
            continue
        fi

        # Check if tap is declared
        local is_declared=false
        for declared_tap in "${declared_taps[@]}"; do
            if [[ "$installed_tap" == "$declared_tap" ]]; then
                is_declared=true
                break
            fi
        done

        # Remove undeclared tap
        if [[ "$is_declared" == "false" ]]; then
            print_info "Removing undeclared tap: $installed_tap"
            brew untap "$installed_tap" 2>/dev/null && ((removed_count++)) || true
        fi
    done < <(brew tap)

    if [[ $removed_count -gt 0 ]]; then
        print_status "Removed $removed_count undeclared tap(s)"
    else
        print_status "All taps are declared in Brewfile"
    fi
}

run_brew_sync() {
    print_header "Syncing Homebrew Packages ($DOTFILES_PROFILE profile)"

    # Inject Brewfile.work and set GitHub token from 1Password if authenticated (work profile only)
    if is_work_profile && command -v op &>/dev/null && op vault list --account my.1password.com &>/dev/null 2>&1; then
        if [[ -f "$DOTFILES/templates/Brewfile.tpl" ]]; then
            print_info "Injecting work Brewfile from 1Password..."
            mkdir -p "$DOTFILES/sensitive"
            op inject -f -i "$DOTFILES/templates/Brewfile.tpl" \
                      -o "$DOTFILES/sensitive/Brewfile.work" \
                      --account my.1password.com 2>/dev/null || true
        fi

        # Set GitHub token for private Homebrew taps
        local gh_token
        if gh_token=$(op read "op://Private/Github Token/password" --account my.1password.com 2>/dev/null); then
            export HOMEBREW_GITHUB_API_TOKEN="$gh_token"
            print_status "GitHub API token configured for Homebrew"
        fi
    elif is_personal_profile; then
        print_info "Personal profile: skipping work-specific Homebrew packages"
    fi

    # Prepare combined Brewfile
    local brewfile
    brewfile=$(prepare_brewfile)

    # Clean up broken and undeclared taps before updating
    check_and_remove_broken_taps
    cleanup_undeclared_taps "$brewfile"

    # Show warning about cleanup
    echo ""
    print_warning "Homebrew will install packages from Brewfile and remove unlisted packages"
    print_info "Packages not in Brewfile will be uninstalled (--cleanup)"
    echo ""

    # Update and sync
    print_info "Updating Homebrew..."
    brew update

    print_info "Installing packages and cleaning up..."
    if brew bundle --file="$brewfile" --cleanup --verbose; then
        print_status "Homebrew packages synced"
    else
        print_warning "Some packages may have failed to install"
    fi

    # Clean up combined Brewfile
    rm -f "$brewfile"
}

# =============================================================================
# Shell & Environment Setup
# =============================================================================

sync_theme() {
    if [[ -x "$DOTFILES/setup/sync-theme.sh" ]]; then
        "$DOTFILES/setup/sync-theme.sh"
    elif [[ -f "$DOTFILES/setup/sync-theme.sh" ]]; then
        bash "$DOTFILES/setup/sync-theme.sh"
    else
        print_warning "sync-theme.sh not found - skipping theme sync"
    fi
}

create_symlinks() {
    print_info "Creating symlinks..."
    if [[ -x "$DOTFILES/setup/symlinks.sh" ]]; then
        source "$DOTFILES/setup/symlinks.sh"
    else
        bash "$DOTFILES/setup/symlinks.sh"
    fi
}

setup_fish_shell() {
    local fish_path
    fish_path=$(get_fish_path)

    if [[ ! -x "$fish_path" ]]; then
        print_warning "Fish shell not found at $fish_path"
        return 1
    fi

    # Add Fish to /etc/shells if not present
    if ! grep -q "$fish_path" /etc/shells 2>/dev/null; then
        print_info "Adding Fish to /etc/shells (requires sudo)..."
        echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # Set Fish as default shell
    if [[ "$SHELL" != "$fish_path" ]]; then
        print_info "Setting Fish as default shell..."
        # Try sudo chsh first (no password prompt), fall back to regular chsh
        if sudo chsh -s "$fish_path" "$USER" 2>/dev/null; then
            print_status "Fish shell: configured (via sudo)"
        elif chsh -s "$fish_path" 2>/dev/null; then
            print_status "Fish shell: configured"
        else
            print_warning "Could not change shell automatically"
            print_info "Run manually: chsh -s $fish_path"
            return 0
        fi
    else
        print_status "Fish shell: already configured"
    fi
}

setup_fisher() {
    if ! command -v fish &>/dev/null; then
        return 0
    fi

    if fish -c "type -q fisher" 2>/dev/null; then
        print_status "Fisher: already installed"
        return 0
    fi

    print_info "Installing Fisher plugin manager..."
    fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
    print_status "Fisher: installed"
}

setup_tmux_plugins() {
    local tpm_dir="$HOME/.tmux/plugins/tpm"

    if [[ -d "$tpm_dir" ]]; then
        print_status "Tmux Plugin Manager: already installed"
        return 0
    fi

    print_info "Installing Tmux Plugin Manager..."
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
    print_status "Tmux Plugin Manager: installed"
}

setup_sketchybar() {
    if ! command -v sketchybar &>/dev/null; then
        print_warning "Sketchybar not installed - skipping"
        return 0
    fi

    # Make sure scripts are executable
    if [[ -d "$DOTFILES/sketchybar" ]]; then
        chmod +x "$DOTFILES/sketchybar/sketchybarrc" 2>/dev/null || true
        chmod +x "$DOTFILES/sketchybar/plugins/"*.sh 2>/dev/null || true
        chmod +x "$DOTFILES/sketchybar/items/"*.sh 2>/dev/null || true
    fi

    local plist="$HOME/Library/LaunchAgents/com.felixkratz.sketchybar.plist"

    # Load the LaunchAgent (symlink created by symlinks.sh)
    if [[ -f "$plist" ]]; then
        # Unload first if already loaded, then reload
        launchctl unload "$plist" 2>/dev/null || true
        launchctl load "$plist"
        print_status "Sketchybar: loaded (starts at login)"
    else
        print_warning "Sketchybar plist not found - run symlinks first"
    fi
}

setup_display_monitor() {
    if ! command -v aerospace &>/dev/null || ! command -v sketchybar &>/dev/null; then
        print_warning "Aerospace or Sketchybar not installed - skipping display monitor"
        return 0
    fi

    # Make scripts executable
    chmod +x "$DOTFILES/setup/monitor-watcher.sh" 2>/dev/null || true
    chmod +x "$DOTFILES/setup/reload-display-config.sh" 2>/dev/null || true
    chmod +x "$DOTFILES/setup/display-profiles.sh" 2>/dev/null || true

    # Create log directory
    mkdir -p "$HOME/.config/logs"

    local plist="$HOME/Library/LaunchAgents/com.user.display-monitor.plist"

    # Load the LaunchAgent (created by secrets.sh)
    if [[ -f "$plist" ]]; then
        # Unload first if already loaded, then reload
        launchctl unload "$plist" 2>/dev/null || true
        launchctl load "$plist"
        print_status "Display monitor: loaded (starts at login)"
    else
        print_warning "Display monitor plist not found - run 'secrets' first"
    fi

    # Apply display profile now (the watcher only triggers on count changes)
    if command -v displayplacer &>/dev/null; then
        print_info "Applying display profile..."
        bash "$DOTFILES/setup/display-profiles.sh"
    fi
}

setup_spotlight_shortcuts() {
    # Make script executable
    chmod +x "$DOTFILES/setup/disable-spotlight-shortcuts.sh" 2>/dev/null || true

    # Create log directory
    mkdir -p "$HOME/.config/logs"

    local plist="$HOME/Library/LaunchAgents/com.user.spotlight-shortcuts.plist"

    # Load the LaunchAgent (created by secrets.sh)
    if [[ -f "$plist" ]]; then
        # Unload first if already loaded, then reload
        launchctl unload "$plist" 2>/dev/null || true
        launchctl load "$plist"
        print_status "Spotlight shortcuts: loaded (runs at login)"
    else
        print_warning "Spotlight shortcuts plist not found - run 'secrets' first"
    fi
}

setup_wallpaper() {
    local wallpaper="$DOTFILES/assets/comfy-home.png"

    if [[ ! -f "$wallpaper" ]]; then
        print_warning "Wallpaper not found at $wallpaper - skipping"
        return 0
    fi

    print_info "Setting wallpaper..."
    osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$wallpaper\""
    print_status "Wallpaper: applied to all desktops"
}

setup_default_browser() {
    # Only set default browser if Waterfox is installed (which happens during brew sync)
    if [[ ! -d "/Applications/Waterfox.app" ]]; then
        print_warning "Waterfox not installed - skipping default browser setup"
        return 0
    fi

    # Check if defaultbrowser is available
    if ! command -v defaultbrowser &>/dev/null; then
        print_warning "defaultbrowser command not found - skipping default browser setup"
        print_info "Run 'brew install defaultbrowser' and re-run setup"
        return 0
    fi

    print_info "Setting Waterfox as default browser..."

    # Set Waterfox as the default browser
    if defaultbrowser waterfox 2>/dev/null; then
        print_status "Waterfox set as default browser"
    else
        print_warning "Could not set Waterfox as default browser"
        print_info "You can set it manually in System Settings > Desktop & Dock > Default web browser"
    fi
}

apply_macos_defaults() {
    if [[ ! -f "$DOTFILES/.macos" ]]; then
        print_error "macOS preferences file not found: $DOTFILES/.macos"
        return 1
    fi

    print_info "Applying macOS preferences..."
    source "$DOTFILES/.macos"
    print_status "macOS preferences applied"
}

# =============================================================================
# Workflow Functions
# =============================================================================

run_setup() {
    print_header "Dotfiles Setup"

    # Detect profile first
    detect_and_validate_profile

    # Prerequisites
    ensure_xcode_clt
    ensure_homebrew
    ensure_dotfiles

    cd "$DOTFILES"

    # Apply macOS preferences first (includes Full Disk Access check for terminal)
    # This must run before Homebrew sync to ensure terminal has required permissions
    apply_macos_defaults

    # Inject secrets (needed for Brewfile.work) - profile-aware
    inject_secrets

    # Declarative Homebrew sync
    run_brew_sync

    # Set default browser (after Waterfox and defaultbrowser are installed via brew)
    setup_default_browser

    # Sync theme colors to all tool configs
    sync_theme

    # Shell and environment
    create_symlinks
    setup_fish_shell
    setup_fisher
    setup_tmux_plugins
    setup_sketchybar
    setup_display_monitor
    setup_spotlight_shortcuts

    # Set wallpaper
    setup_wallpaper

    # Reload window manager configs
    if command -v aerospace &>/dev/null; then
        aerospace reload-config 2>/dev/null || true
        print_status "Aerospace: config reloaded"
    fi
    if command -v sketchybar &>/dev/null; then
        sketchybar --reload 2>/dev/null || true
        print_status "Sketchybar: reloaded"
    fi

    # Show completion message
    print_header "Setup Complete!"
    echo "Next steps:"
    echo "  1. Restart your terminal to use Fish shell"
    echo "  2. Run 'tmux' and press prefix + I to install tmux plugins"
    if ! command -v op &>/dev/null || ! op vault list --account my.1password.com &>/dev/null 2>&1; then
        echo "  3. Set up secrets from 1Password:"
        echo "     - Sign in: op signin"
        echo "     - Run: secrets"
    fi
    echo ""
}

run_brew() {
    print_header "Homebrew Sync"

    # Detect profile first
    detect_and_validate_profile

    cd "$DOTFILES"

    # Try to inject Brewfile.work if 1Password is available (work profile only)
    if is_work_profile && command -v op &>/dev/null; then
        if ! op vault list --account my.1password.com &>/dev/null 2>&1; then
            # Skip prompt in non-interactive mode
            if [[ -t 0 ]]; then
                echo ""
                read -p "Sign in to 1Password for work tools? (y/n) " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    eval "$(op signin 2>/dev/null)" || true
                fi
            fi
        fi
    fi

    run_brew_sync

    # Set default browser after brew sync
    setup_default_browser

    print_header "Homebrew Sync Complete!"
}

run_macos() {
    print_header "macOS Preferences"

    # Detect profile first (needed for hostname)
    detect_and_validate_profile

    cd "$DOTFILES"

    apply_macos_defaults

    print_header "macOS Preferences Applied!"
    echo "Note: Some changes require a logout/restart to take effect."
    echo ""
}

show_help() {
    cat << EOF
Dotfiles Setup Script (Idempotent, Multi-Machine)

Usage:
  ./setup.sh                      Run full setup (auto-detect profile)
  ./setup.sh --profile <profile>  Override profile (work or personal)
  ./setup.sh --brew               Sync Homebrew packages only
  ./setup.sh --macos              Apply macOS preferences only
  ./setup.sh --help               Show this help message

Profiles:
  Profile is auto-detected from hostname:
    hera   -> work (includes work tools and secrets)
    athena -> personal (skips work-specific items)

  Use --profile to override: ./setup.sh --profile personal

Full Setup:
  Runs all setup tasks idempotently:
  - Installs Xcode CLT and Homebrew (if missing)
  - Clones dotfiles repository (if missing)
  - Injects secrets from 1Password (work profile only)
  - Syncs Homebrew packages (declarative with --cleanup)
  - Creates symlinks
  - Configures Fish shell as default
  - Installs Fisher and TPM
  - Applies macOS system preferences

Homebrew Sync (--brew):
  Installs packages from Brewfile and removes packages not in Brewfile.
  Work-only packages (marked with @profile:work) are skipped on personal profile.

macOS Preferences (--macos):
  Applies system preferences: UI, input, sound, Finder, screenshots, etc.
  Hostname is set based on detected or overridden profile.

1Password Integration (work profile only):
  Work tools from templates/Brewfile.tpl require 1Password authentication.
  The script will prompt to sign in if needed, or you can skip and run
  'secrets' later.

EOF
}

# =============================================================================
# Main
# =============================================================================

main() {
    local mode="setup"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile|-p)
                shift
                if [[ $# -eq 0 ]]; then
                    print_error "--profile requires a value (work or personal)"
                    exit 1
                fi
                PROFILE_OVERRIDE="$1"
                ;;
            --brew|-b)
                mode="brew"
                ;;
            --macos|-m)
                mode="macos"
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run './setup.sh --help' for usage information."
                exit 1
                ;;
        esac
        shift
    done

    # Execute selected mode
    case $mode in
        setup)
            run_setup
            ;;
        brew)
            run_brew
            ;;
        macos)
            run_macos
            ;;
    esac
}

main "$@"
