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
#   ~/.config/.system/setup/secrets.sh           # Inject all secrets
#   ~/.config/.system/setup/secrets.sh --check   # Check if secrets are configured
#

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"
TEMPLATES_DIR="$SYSTEM_DIR/templates"
SENSITIVE_DIR="$SYSTEM_DIR/sensitive"

# 1Password account identifiers
OP_PERSONAL_ACCOUNT="my.1password.com"

# Source shared output utilities
source "$SYSTEM_DIR/setup/lib/output.sh"

# Source hostname utilities
source "$SYSTEM_DIR/setup/lib/profiles.sh"

# Use hostname from environment or auto-detect
MACHINE_HOSTNAME="${MACHINE_HOSTNAME:-$(hostname -s)}"

# Check if 1Password CLI is installed and authenticated
check_op() {
    if ! command -v op &>/dev/null; then
        print_error "1Password CLI (op) is not installed"
        echo "  Install with: brew install 1password-cli"
        exit 1
    fi

    if ! op vault list --account "$OP_PERSONAL_ACCOUNT" &>/dev/null; then
        print_error "Not signed in to 1Password ($OP_PERSONAL_ACCOUNT)"
        echo "  Sign in with: op signin --account $OP_PERSONAL_ACCOUNT"
        exit 1
    fi
}

# Inject secrets from a template file
# Usage: inject_template <template> <output> <description> [account]
inject_template() {
    local template="$1"
    local output="$2"
    local description="$3"
    local account="${4:-}"

    if [[ ! -f "$template" ]]; then
        print_warning "Template not found: $template"
        return 1
    fi

    echo "  Injecting $description..."

    # Create output directory if needed
    mkdir -p "$(dirname "$output")"

    # Use op inject to replace op:// references with actual values
    # --force allows overwriting existing files without prompting
    local op_args=(-f -i "$template" -o "$output")
    if [[ -n "$account" ]]; then
        op_args+=(--account "$account")
    fi

    if op inject "${op_args[@]}"; then
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
    username=$(op read "op://Private/Atuin/username" --account "$OP_PERSONAL_ACCOUNT" 2>/dev/null) || {
        print_warning "Atuin credentials not found in 1Password (Private/Atuin)"
        return 1
    }
    password=$(op read "op://Private/Atuin/password" --account "$OP_PERSONAL_ACCOUNT" 2>/dev/null) || {
        print_error "Failed to read Atuin password from 1Password"
        return 1
    }
    key=$(op read "op://Private/Atuin/key" --account "$OP_PERSONAL_ACCOUNT" 2>/dev/null) || {
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
    local work_skills="argocd:claude-skill-argocd astro:claude-skill-astro bastion_zero:claude-skill-bastion_zero lrl-cli:claude-skill-lrl-cli observe:claude-skill-observe spacectl:claude-skill-spacectl prod-release:claude-skill-prod-release prod-version:claude-skill-prod-version"

    for pair in $work_skills; do
        local skill_name="${pair%%:*}"
        local doc_title="${pair#*:}"
        local output_dir="$CLAUDE_SKILLS_OUTPUT/$skill_name"
        local output_file="$output_dir/SKILL.md"
        local temp_file

        mkdir -p "$output_dir"
        temp_file=$(mktemp)

        # Download from 1Password to temp file (--force avoids op's built-in prompt)
        if ! op document get "$doc_title" --output "$temp_file" --force --account "$OP_WORK_ACCOUNT" 2>/dev/null; then
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
        print_warning "$skill_name skill has changed:"
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
                if op document edit "$doc_title" --file-path "$output_file" --account "$OP_WORK_ACCOUNT" 2>/dev/null; then
                    print_status "  $skill_name skill: local version pushed to 1Password"
                else
                    print_warning "  $skill_name skill: kept local (failed to push to 1Password)"
                fi
                ;;
        esac
    done
}

# Retrieve a Claude skill archive (tarball) from 1Password
# Used for multi-file skills that can't be stored as a single document
inject_claude_skill_archive() {
    local doc_title="$1"
    local skill_name="$2"
    local output_dir="$SENSITIVE_DIR/claude-skills/$skill_name"
    local temp_file

    temp_file=$(mktemp)

    # Download tarball from 1Password
    if ! op document get "$doc_title" --output "$temp_file" --force --account "$OP_WORK_ACCOUNT" 2>/dev/null; then
        rm -f "$temp_file"
        print_warning "  $skill_name skill archive not found in 1Password (document: $doc_title)"
        return 1
    fi

    # If directory exists, extract to temp and compare
    if [[ -d "$output_dir" ]]; then
        local temp_extract
        temp_extract=$(mktemp -d)
        if tar xf "$temp_file" -C "$temp_extract" 2>/dev/null; then
            if diff -rq "$output_dir" "$temp_extract" >/dev/null 2>&1; then
                rm -rf "$temp_extract" "$temp_file"
                print_status "  $skill_name skill archive unchanged"
                return 0
            fi
            rm -rf "$temp_extract"
        else
            rm -rf "$temp_extract" "$temp_file"
            print_error "  $skill_name skill archive is not a valid tarball"
            return 1
        fi
    fi

    # Extract tarball to output directory (clean first to remove stale files)
    rm -rf "$output_dir"
    mkdir -p "$output_dir"
    if tar xf "$temp_file" -C "$output_dir" 2>/dev/null; then
        find "$output_dir" -type d -exec chmod 700 {} \;
        find "$output_dir" -type f -exec chmod 600 {} \;
        rm -f "$temp_file"
        print_status "  $skill_name skill archive extracted"
    else
        rm -f "$temp_file"
        print_error "  Failed to extract $skill_name skill archive"
        return 1
    fi
}

# Check which secrets are configured
check_secrets() {
    echo ""
    echo "Checking secrets configuration ($MACHINE_HOSTNAME)..."
    echo ""

    local all_configured=true

    # Check GitHub hosts (optional - gh auth login is preferred)
    if [[ -f "$HOME/.config/gh/hosts.yml" ]]; then
        print_status "GitHub CLI: configured"
    else
        print_warning "GitHub CLI: not configured (run 'gh auth login')"
    fi

    # Work-only secrets (work group machines)
    if is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
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

        # Check clone function
        if [[ -f "$DOTFILES/fish/functions/clone.fish" ]]; then
            print_status "Clone function: configured"
        else
            print_warning "Clone function: not configured"
            all_configured=false
        fi

        # Check work-specific Claude skills
        local work_skills=("argocd" "astro" "bastion_zero" "lrl-cli" "observe" "spacectl" "prod-release" "prod-version" "notion-research-documentation")
        for skill in "${work_skills[@]}"; do
            if [[ -d "$DOTFILES/claude/skills/$skill" ]] || [[ -d "$SENSITIVE_DIR/claude-skills/$skill" ]]; then
                print_status "Claude skill: $skill configured"
            else
                print_warning "Claude skill: $skill not configured"
                all_configured=false
            fi
        done

        # Check Claude Code telemetry
        if [[ -f "$HOME/Library/Application Support/ClaudeCode/managed-settings.json" ]]; then
            print_status "Claude Code telemetry: configured"
        else
            print_warning "Claude Code telemetry: not configured"
            all_configured=false
        fi
    else
        print_info "$MACHINE_HOSTNAME: work-only secrets not checked (zli, ci-identity, clone, claude skills)"
    fi

    # Secrets for all machines
    # Check fastfetch logo symlink
    if [[ -L "$DOTFILES/fastfetch/logo.txt" ]]; then
        local target
        target=$(readlink "$DOTFILES/fastfetch/logo.txt")
        print_status "Fastfetch logo: linked to $(basename "$target")"
    else
        print_warning "Fastfetch logo: not configured"
        all_configured=false
    fi

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

    # Check spotlight shortcuts LaunchAgent
    if [[ -f "$HOME/Library/LaunchAgents/com.user.spotlight-shortcuts.plist" ]]; then
        print_status "Spotlight shortcuts LaunchAgent: configured"
    else
        print_warning "Spotlight shortcuts LaunchAgent: not configured"
        all_configured=false
    fi

    # Check sketchybar LaunchAgent
    if [[ -f "$HOME/Library/LaunchAgents/com.felixkratz.sketchybar.plist" ]]; then
        print_status "Sketchybar LaunchAgent: configured"
    else
        print_warning "Sketchybar LaunchAgent: not configured"
        all_configured=false
    fi

    # Server-specific checks
    if is_machine_in_group "$MACHINE_HOSTNAME" "server"; then
        if [[ -f "$SENSITIVE_DIR/rustdesk-password" ]]; then
            print_status "RustDesk password: configured"
        else
            print_warning "RustDesk password: not configured"
            all_configured=false
        fi

        if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
            print_status "Tailscale: authenticated"
        else
            print_warning "Tailscale: not authenticated (run 'tailscale up')"
            all_configured=false
        fi
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
    echo "  1Password Secrets Injection ($MACHINE_HOSTNAME)"
    echo "=========================================="
    echo ""

    check_op

    # Read work account domain from personal vault (work group machines only)
    OP_WORK_ACCOUNT=""
    if is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
        OP_WORK_ACCOUNT=$(op read "op://Private/1password-work-account/domain" \
            --account "$OP_PERSONAL_ACCOUNT") || {
            print_error "Failed to read work 1Password account domain"
            print_info "Ensure '1password-work-account' item exists in Private vault"
            exit 1
        }
    fi

    # Ensure directories exist
    mkdir -p "$SENSITIVE_DIR"
    mkdir -p "$TEMPLATES_DIR"

    # Inject GitHub hosts (optional - usually use gh auth login instead)
    if [[ -f "$TEMPLATES_DIR/gh-hosts.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/gh-hosts.tpl" "$HOME/.config/gh/hosts.yml" "GitHub CLI credentials"
    fi

    # Work-only secrets (work group machines)
    if is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
        # Inject ZLI connect command
        if [[ -f "$TEMPLATES_DIR/zli.tpl" ]]; then
            inject_template "$TEMPLATES_DIR/zli.tpl" "$SENSITIVE_DIR/zli-command" "ZLI connect command" "$OP_PERSONAL_ACCOUNT"
        fi

        # Inject CI identity for empty commits
        if [[ -f "$TEMPLATES_DIR/ci-identity.tpl" ]]; then
            inject_template "$TEMPLATES_DIR/ci-identity.tpl" "$SENSITIVE_DIR/ci-identity" "CI identity" "$OP_PERSONAL_ACCOUNT"
        fi

        # Inject clone.fish with work org
        if [[ -f "$TEMPLATES_DIR/clone.fish.tpl" ]]; then
            inject_template "$TEMPLATES_DIR/clone.fish.tpl" "$DOTFILES/fish/functions/clone.fish" "Clone function" "$OP_PERSONAL_ACCOUNT"
        fi

        # Retrieve work-specific Claude skills from 1Password
        inject_claude_skills

        # Retrieve multi-file skill archives from 1Password
        inject_claude_skill_archive "claude-skill-notion-research-documentation" "notion-research-documentation"

        # Claude Code telemetry (WorkWeave OTEL)
        # Uses work 1Password account for Engineering Account Credentials vault
        local claude_code_dir="$HOME/Library/Application Support/ClaudeCode"
        mkdir -p "$claude_code_dir"
        inject_template "$TEMPLATES_DIR/managed-settings.tpl" \
            "$claude_code_dir/managed-settings.json" \
            "Claude Code telemetry" \
            "$OP_WORK_ACCOUNT"
    else
        print_info "$MACHINE_HOSTNAME: skipping work-only secrets (zli, ci-identity, clone, claude skills)"
    fi

    # RustDesk permanent password (server machines)
    if is_machine_in_group "$MACHINE_HOSTNAME" "server"; then
        if [[ -f "$TEMPLATES_DIR/rustdesk-password.tpl" ]]; then
            inject_template "$TEMPLATES_DIR/rustdesk-password.tpl" "$SENSITIVE_DIR/rustdesk-password" "RustDesk password" "$OP_PERSONAL_ACCOUNT"
        fi
    fi

    # Secrets for all machines
    # Symlink fastfetch logo based on hostname
    local logo_target="logo_${MACHINE_HOSTNAME}.txt"
    ln -sf "$DOTFILES/fastfetch/$logo_target" "$DOTFILES/fastfetch/logo.txt"
    print_status "Fastfetch logo: $logo_target"

    # Inject git config with identity
    if [[ -f "$TEMPLATES_DIR/git-config.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/git-config.tpl" "$DOTFILES/git/config" "Git identity" "$OP_PERSONAL_ACCOUNT"
    fi

    # Inject display monitor LaunchAgent
    if [[ -f "$TEMPLATES_DIR/display-monitor.plist.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/display-monitor.plist.tpl" "$HOME/Library/LaunchAgents/com.user.display-monitor.plist" "Display monitor LaunchAgent" "$OP_PERSONAL_ACCOUNT"
    fi

    # Inject spotlight shortcuts LaunchAgent
    if [[ -f "$TEMPLATES_DIR/spotlight-shortcuts.plist.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/spotlight-shortcuts.plist.tpl" "$HOME/Library/LaunchAgents/com.user.spotlight-shortcuts.plist" "Spotlight shortcuts LaunchAgent" "$OP_PERSONAL_ACCOUNT"
    fi

    # Inject sketchybar LaunchAgent
    if [[ -f "$TEMPLATES_DIR/sketchybar.plist.tpl" ]]; then
        inject_template "$TEMPLATES_DIR/sketchybar.plist.tpl" "$HOME/Library/LaunchAgents/com.felixkratz.sketchybar.plist" "Sketchybar LaunchAgent" "$OP_PERSONAL_ACCOUNT"
    fi

    # Login to Atuin sync (all machines)
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
