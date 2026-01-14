#!/usr/bin/env bash
#
# secrets.sh - Manage secrets using 1Password CLI
#
# This script injects secrets from 1Password into local config files.
# Template files use op:// references that get replaced with actual values.
#
# Prerequisites:
#   - 1Password CLI (op) installed
#   - Signed in to 1Password: `op signin`
#
# Usage:
#   ~/.config/setup/secrets.sh           # Inject all secrets
#   ~/.config/setup/secrets.sh --check   # Check if secrets are configured
#

set -eo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
TEMPLATES_DIR="$DOTFILES/templates"
SENSITIVE_DIR="$DOTFILES/sensitive"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if 1Password CLI is installed and authenticated
check_op() {
    if ! command -v op &>/dev/null; then
        print_error "1Password CLI (op) is not installed"
        echo "  Install with: brew install 1password-cli"
        exit 1
    fi

    if ! op account list &>/dev/null; then
        print_error "Not signed in to 1Password"
        echo "  Sign in with: op signin"
        exit 1
    fi
}

# Inject secrets from a template file
inject_template() {
    local template="$1"
    local output="$2"
    local description="$3"

    if [[ ! -f "$template" ]]; then
        print_warning "Template not found: $template"
        return 1
    fi

    echo "  Injecting $description..."

    # Create output directory if needed
    mkdir -p "$(dirname "$output")"

    # Use op inject to replace op:// references with actual values
    # --force allows overwriting existing files without prompting
    if op inject -f -i "$template" -o "$output" 2>/dev/null; then
        chmod 600 "$output"
        print_status "$description configured"
    else
        print_error "Failed to inject $description"
        return 1
    fi
}

# Login to Atuin sync using 1Password credentials
inject_atuin() {
    if ! command -v atuin &>/dev/null; then
        print_warning "Atuin is not installed, skipping sync setup"
        return 0
    fi

    # Check if already logged in (session file exists or status reports sync enabled)
    if [[ -f "$HOME/.local/share/atuin/session" ]]; then
        print_status "Atuin: already logged in (session exists)"
        return 0
    fi
    if atuin status 2>/dev/null | grep -q "Sync enabled"; then
        print_status "Atuin: already logged in"
        return 0
    fi

    echo "  Logging into Atuin sync..."

    local username password key
    username=$(op read "op://Private/Atuin/username" 2>/dev/null) || {
        print_warning "Atuin credentials not found in 1Password (Private/Atuin)"
        return 1
    }
    password=$(op read "op://Private/Atuin/password" 2>/dev/null) || {
        print_error "Failed to read Atuin password from 1Password"
        return 1
    }
    key=$(op read "op://Private/Atuin/key" 2>/dev/null) || {
        print_error "Failed to read Atuin key from 1Password"
        return 1
    }

    if atuin login -u "$username" -p "$password" -k "$key" 2>/dev/null; then
        print_status "Atuin sync configured"
        # Trigger initial sync
        atuin sync 2>/dev/null || true
    else
        print_error "Failed to login to Atuin"
        return 1
    fi
}

# Check which secrets are configured
check_secrets() {
    echo ""
    echo "Checking secrets configuration..."
    echo ""

    local all_configured=true

    # Check GitHub hosts (optional - gh auth login is preferred)
    if [[ -f "$HOME/.config/gh/hosts.yml" ]]; then
        print_status "GitHub CLI: configured"
    else
        print_warning "GitHub CLI: not configured (run 'gh auth login')"
    fi

    # Check ZLI command
    if [[ -f "$SENSITIVE_DIR/zli-command" ]]; then
        print_status "ZLI connect: configured"
    else
        print_warning "ZLI connect: not configured"
        all_configured=false
    fi

    # Check Git identity
    if grep -q "email = ." "$DOTFILES/git/config" 2>/dev/null && ! grep -q "email = $" "$DOTFILES/git/config" 2>/dev/null; then
        print_status "Git identity: configured"
    else
        print_warning "Git identity: not configured"
        all_configured=false
    fi

    # Check CI identity
    if [[ -f "$SENSITIVE_DIR/ci-identity" ]]; then
        print_status "CI identity: configured"
    else
        print_warning "CI identity: not configured"
        all_configured=false
    fi

    # Check Work CLI Brewfile
    if [[ -f "$SENSITIVE_DIR/Brewfile.work" ]]; then
        print_status "Work CLI Brewfile: configured"
    else
        print_warning "Work CLI Brewfile: not configured"
        all_configured=false
    fi

    # Check Atuin sync status
    if command -v atuin &>/dev/null; then
        if atuin status 2>/dev/null | grep -q "Sync enabled"; then
            print_status "Atuin sync: logged in"
        else
            print_warning "Atuin sync: not logged in"
            all_configured=false
        fi
    else
        print_warning "Atuin: not installed"
    fi

    echo ""
    if $all_configured; then
        print_status "All secrets configured"
    else
        print_warning "Some secrets are missing. Run this script without --check to configure."
    fi
}

# Main injection routine
inject_secrets() {
    echo ""
    echo "=========================================="
    echo "  1Password Secrets Injection"
    echo "=========================================="
    echo ""

    check_op

    # Ensure directories exist
    mkdir -p "$SENSITIVE_DIR"
    mkdir -p "$TEMPLATES_DIR"

    # Inject GitHub hosts (optional - usually use gh auth login instead)
    if [[ -f "$TEMPLATES_DIR/gh-hosts.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/gh-hosts.tpl" "$HOME/.config/gh/hosts.yml" "GitHub CLI credentials"
    fi

    # Inject ZLI connect command
    if [[ -f "$TEMPLATES_DIR/zli.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/zli.tpl" "$SENSITIVE_DIR/zli-command" "ZLI connect command"
    fi

    # Inject git config with identity
    if [[ -f "$TEMPLATES_DIR/git-config.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/git-config.tpl" "$DOTFILES/git/config" "Git identity"
    fi

    # Inject CI identity for empty commits
    if [[ -f "$TEMPLATES_DIR/ci-identity.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/ci-identity.tpl" "$SENSITIVE_DIR/ci-identity" "CI identity"
    fi

    # Inject Work CLI additions for Brewfile
    if [[ -f "$TEMPLATES_DIR/Brewfile.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/Brewfile.tpl" "$SENSITIVE_DIR/Brewfile.work" "Work CLI Brewfile"
        echo "  Note: Run 'brew bundle --file=$SENSITIVE_DIR/Brewfile.work' to install work tools"
    fi

    # Inject clone.fish with work org
    if [[ -f "$TEMPLATES_DIR/clone.fish.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/clone.fish.tpl" "$DOTFILES/fish/functions/clone.fish" "Clone function"
    fi

    # Login to Atuin sync
    inject_atuin

    echo ""
    echo "=========================================="
    echo "  Secrets Injection Complete"
    echo "=========================================="
    echo ""
}

# Parse arguments
case "${1:-}" in
    --check|-c)
        check_secrets
        ;;
    --help|-h)
        echo "Usage: $0 [--check|--help]"
        echo ""
        echo "Options:"
        echo "  --check, -c    Check which secrets are configured"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Without arguments, injects all secrets from 1Password."
        ;;
    *)
        inject_secrets
        ;;
esac
