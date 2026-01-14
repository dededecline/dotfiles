#!/usr/bin/env bash
#
# setup.sh - Unified dotfiles setup script (idempotent)
#
# Usage:
#   ./setup.sh              # Run full setup
#   ./setup.sh --brew       # Sync Homebrew packages only
#   ./setup.sh --macos      # Apply macOS preferences only
#   ./setup.sh --help       # Show usage
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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =============================================================================
# Utility Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}===========================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}===========================================================${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "  $1"
}

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

    if op account list &>/dev/null 2>&1; then
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
            if op account list &>/dev/null 2>&1; then
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

    # Start with base Brewfile
    cat "$DOTFILES/Brewfile" > "$combined"

    # Append work Brewfile if it exists
    if [[ -f "$DOTFILES/sensitive/Brewfile.work" ]]; then
        echo "" >> "$combined"
        echo "# Work additions (from 1Password)" >> "$combined"
        cat "$DOTFILES/sensitive/Brewfile.work" >> "$combined"
    fi

    echo "$combined"
}

run_brew_sync() {
    print_header "Syncing Homebrew Packages"

    # Inject Brewfile.work and set GitHub token from 1Password if authenticated
    if command -v op &>/dev/null && op account list &>/dev/null 2>&1; then
        if [[ -f "$DOTFILES/templates/Brewfile.tpl" ]]; then
            print_info "Injecting work Brewfile from 1Password..."
            mkdir -p "$DOTFILES/sensitive"
            op inject -f -i "$DOTFILES/templates/Brewfile.tpl" \
                      -o "$DOTFILES/sensitive/Brewfile.work" 2>/dev/null || true
        fi

        # Set GitHub token for private Homebrew taps
        local gh_token
        if gh_token=$(op read "op://Private/Github Token/password" 2>/dev/null); then
            export HOMEBREW_GITHUB_API_TOKEN="$gh_token"
            print_status "GitHub API token configured for Homebrew"
        fi
    fi

    # Prepare combined Brewfile
    local brewfile
    brewfile=$(prepare_brewfile)

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

setup_aerospace_swipe() {
    if [[ -f "$HOME/.local/bin/aerospace-swipe" ]]; then
        print_status "aerospace-swipe: already installed"
        return 0
    fi

    print_info "Installing aerospace-swipe..."
    curl -sSL https://raw.githubusercontent.com/acsandmann/aerospace-swipe/main/install.sh | bash
    print_status "aerospace-swipe: installed"
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

setup_wallpaper() {
    local wallpaper_dir="$DOTFILES/themes/wallpapers"
    local wallpaper="$wallpaper_dir/comfy-home.png"

    if [[ ! -f "$wallpaper" ]]; then
        print_info "Downloading wallpaper..."
        mkdir -p "$wallpaper_dir"
        curl -fsSL "https://raw.githubusercontent.com/dededecline/nix-config/main/theming/wallpapers/comfy-home.png" \
            -o "$wallpaper"
    fi

    print_info "Setting wallpaper..."
    osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$wallpaper\""
    print_status "Wallpaper: applied to all desktops"
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

    # Prerequisites
    ensure_xcode_clt
    ensure_homebrew
    ensure_dotfiles

    cd "$DOTFILES"

    # Inject secrets (needed for Brewfile.work)
    inject_secrets

    # Declarative Homebrew sync
    run_brew_sync

    # Shell and environment
    create_symlinks
    setup_fish_shell
    setup_fisher
    setup_tmux_plugins
    setup_aerospace_swipe
    setup_sketchybar

    # Apply macOS preferences
    apply_macos_defaults

    # Set wallpaper
    setup_wallpaper

    # Show completion message
    print_header "Setup Complete!"
    echo "Next steps:"
    echo "  1. Restart your terminal to use Fish shell"
    echo "  2. Run 'tmux' and press prefix + I to install tmux plugins"
    if ! command -v op &>/dev/null || ! op account list &>/dev/null 2>&1; then
        echo "  3. Set up secrets from 1Password:"
        echo "     - Sign in: op signin"
        echo "     - Run: secrets"
    fi
    echo ""
}

run_brew() {
    print_header "Homebrew Sync"

    cd "$DOTFILES"

    # Try to inject Brewfile.work if 1Password is available
    if command -v op &>/dev/null; then
        if ! op account list &>/dev/null 2>&1; then
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

    print_header "Homebrew Sync Complete!"
}

run_macos() {
    print_header "macOS Preferences"

    cd "$DOTFILES"

    apply_macos_defaults

    print_header "macOS Preferences Applied!"
    echo "Note: Some changes require a logout/restart to take effect."
    echo ""
}

show_help() {
    cat << EOF
Dotfiles Setup Script (Idempotent)

Usage:
  ./setup.sh              Run full setup
  ./setup.sh --brew       Sync Homebrew packages only
  ./setup.sh --macos      Apply macOS preferences only
  ./setup.sh --help       Show this help message

Full Setup:
  Runs all setup tasks idempotently:
  - Installs Xcode CLT and Homebrew (if missing)
  - Clones dotfiles repository (if missing)
  - Injects secrets from 1Password (if authenticated)
  - Syncs Homebrew packages (declarative with --cleanup)
  - Creates symlinks
  - Configures Fish shell as default
  - Installs Fisher, TPM, and aerospace-swipe
  - Applies macOS system preferences

Homebrew Sync (--brew):
  Installs packages from Brewfile and removes packages not in Brewfile.

macOS Preferences (--macos):
  Applies system preferences: UI, input, sound, Finder, screenshots, etc.

1Password Integration:
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
