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

# Source shared output utilities
source "$DOTFILES/setup/lib/output.sh"

# Source profile utilities
source "$DOTFILES/setup/lib/profiles.sh"

# Use profile from environment or default to work (for backwards compatibility)
DOTFILES_PROFILE="${DOTFILES_PROFILE:-work}"

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

# Retrieve work-specific Claude skills from 1Password
# Uses diff-based comparison to avoid unnecessary prompts
inject_claude_skills() {
    local CLAUDE_SKILLS_OUTPUT="$SENSITIVE_DIR/claude-skills"

    echo "  Retrieving work-specific Claude skills from 1Password..."

    # Work skills: skill_name:doc_title pairs
    local work_skills="argocd:claude-skill-argocd astro:claude-skill-astro bastion_zero:claude-skill-bastion_zero lrl-cli:claude-skill-lrl-cli observe:claude-skill-observe spacectl:claude-skill-spacectl"

    for pair in $work_skills; do
        local skill_name="${pair%%:*}"
        local doc_title="${pair#*:}"
        local output_dir="$CLAUDE_SKILLS_OUTPUT/$skill_name"
        local output_file="$output_dir/SKILL.md"
        local temp_file

        mkdir -p "$output_dir"
        temp_file=$(mktemp)

        # Download from 1Password to temp file (--force avoids op's built-in prompt)
        if ! op document get "$doc_title" --output "$temp_file" --force 2>/dev/null; then
            rm -f "$temp_file"
            print_warning "  $skill_name skill not found in 1Password (document: $doc_title)"
            continue
        fi

        # If local file doesn't exist, just move temp to output
        if [[ ! -f "$output_file" ]]; then
            mv "$temp_file" "$output_file"
            chmod 600 "$output_file"
            print_status "  $skill_name skill retrieved (new)"
            continue
        fi

        # Compare files
        if diff -q "$output_file" "$temp_file" >/dev/null 2>&1; then
            # Files are identical - skip
            rm -f "$temp_file"
            print_status "  $skill_name skill unchanged"
            continue
        fi

        # Files differ - show diff and prompt
        echo ""
        echo -e "${YELLOW}$skill_name skill has changed:${NC}"
        echo "─────────────────────────────────────────"
        diff --color=auto -u "$output_file" "$temp_file" | head -50 || true
        echo "─────────────────────────────────────────"
        echo ""
        echo "Choose action:"
        echo "  [l] Keep local version"
        echo "  [r] Use remote (1Password) version"
        echo ""
        read -rp "Action [l/r]: " choice

        case "$choice" in
            r|R)
                mv "$temp_file" "$output_file"
                chmod 600 "$output_file"
                print_status "  $skill_name skill updated from 1Password"
                ;;
            l|L|*)
                rm -f "$temp_file"
                # Push local version back to 1Password
                if op document edit "$doc_title" --file-path "$output_file" 2>/dev/null; then
                    print_status "  $skill_name skill: local version pushed to 1Password"
                else
                    print_warning "  $skill_name skill: kept local (failed to push to 1Password)"
                fi
                ;;
        esac
    done
}

# Check which secrets are configured
check_secrets() {
    echo ""
    echo "Checking secrets configuration ($DOTFILES_PROFILE profile)..."
    echo ""

    local all_configured=true

    # Check GitHub hosts (optional - gh auth login is preferred)
    if [[ -f "$HOME/.config/gh/hosts.yml" ]]; then
        print_status "GitHub CLI: configured"
    else
        print_warning "GitHub CLI: not configured (run 'gh auth login')"
    fi

    # Work-only secrets
    if is_work_profile; then
        # Check ZLI command
        if [[ -f "$SENSITIVE_DIR/zli-command" ]]; then
            print_status "ZLI connect: configured"
        else
            print_warning "ZLI connect: not configured"
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

        # Check clone function
        if [[ -f "$DOTFILES/fish/functions/clone.fish" ]]; then
            print_status "Clone function: configured"
        else
            print_warning "Clone function: not configured"
            all_configured=false
        fi

        # Check work-specific Claude skills
        local work_skills=("argocd" "astro" "bastion_zero" "lrl-cli" "observe" "spacectl")
        for skill in "${work_skills[@]}"; do
            if [[ -d "$DOTFILES/claude/skills/$skill" ]]; then
                print_status "Claude skill: $skill configured"
            else
                print_warning "Claude skill: $skill not configured"
                all_configured=false
            fi
        done
    else
        print_info "Personal profile: work-only secrets not checked (zli, ci-identity, Brewfile.work, clone, claude skills)"
    fi

    # Secrets for all profiles
    # Check Git identity
    if grep -q "email = ." "$DOTFILES/git/config" 2>/dev/null && ! grep -q "email = $" "$DOTFILES/git/config" 2>/dev/null; then
        print_status "Git identity: configured"
    else
        print_warning "Git identity: not configured"
        all_configured=false
    fi

    # Check display monitor LaunchAgent
    if [[ -f "$HOME/Library/LaunchAgents/com.user.display-monitor.plist" ]]; then
        print_status "Display monitor LaunchAgent: configured"
    else
        print_warning "Display monitor LaunchAgent: not configured"
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
    echo "  1Password Secrets Injection ($DOTFILES_PROFILE profile)"
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

    # Work-only secrets
    if is_work_profile; then
        # Inject ZLI connect command
        if [[ -f "$TEMPLATES_DIR/zli.tpl" ]]; then
            inject_template "$TEMPLATES_DIR/zli.tpl" "$SENSITIVE_DIR/zli-command" "ZLI connect command"
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

        # Retrieve work-specific Claude skills from 1Password
        inject_claude_skills
    else
        print_info "Personal profile: skipping work-only secrets (zli, ci-identity, Brewfile.work, clone, claude skills)"
    fi

    # Secrets for all profiles
    # Inject git config with identity
    if [[ -f "$TEMPLATES_DIR/git-config.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/git-config.tpl" "$DOTFILES/git/config" "Git identity"
    fi

    # Inject display monitor LaunchAgent
    if [[ -f "$TEMPLATES_DIR/display-monitor.plist.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/display-monitor.plist.tpl" "$HOME/Library/LaunchAgents/com.user.display-monitor.plist" "Display monitor LaunchAgent"
    fi

    # Login to Atuin sync (both profiles)
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
