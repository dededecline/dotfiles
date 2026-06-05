#!/usr/bin/env bash
#
# Unified dotfiles setup script (idempotent)
#
# Usage:
#   ./setup.sh                      # Run full setup (auto-detect from hostname)
#   ./setup.sh --hostname athena    # Override hostname
#   ./setup.sh --brew               # Sync Homebrew packages only
#   ./setup.sh --macos              # Apply macOS preferences only
#   ./setup.sh --help               # Show usage
#
# Supported machines: defined by .system/profiles/profiles.toml
# Machine groups: defined by .system/profiles/profiles.toml (hostname → group list)
#
# For fresh installs from a new machine:
#   curl -fsSL https://raw.githubusercontent.com/dededecline/dotfiles/main/setup.sh | bash
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"
export SYSTEM_DIR

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
if [[ -f "$SYSTEM_DIR/setup/lib/output.sh" ]]; then
  source "$SYSTEM_DIR/setup/lib/output.sh"
else
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
  print_header() { echo -e "\n${BLUE}===========================================================${NC}\n${BLUE}  $1${NC}\n${BLUE}===========================================================${NC}\n"; }
  print_status() { echo -e "${GREEN}✓${NC} $1"; }
  print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
  print_error() { echo -e "${RED}✗${NC} $1"; }
  print_info() { echo -e "  $1"; }
fi

# Source hostname utilities (deferred for fresh installs where repo isn't cloned yet)
_PROFILES_LOADED=false

ensure_profiles_loaded() {
  if [[ "$_PROFILES_LOADED" == "true" ]]; then
    return 0
  fi
  if [[ -f "$SYSTEM_DIR/setup/lib/profiles.sh" ]]; then
    source "$SYSTEM_DIR/setup/lib/profiles.sh"
    _PROFILES_LOADED=true
  else
    print_error "profiles.sh not found, dotfiles repo may not be cloned"
    print_info "Expected at: $SYSTEM_DIR/setup/lib/profiles.sh"
    exit 1
  fi
}

# Source immediately if available (covers local ./setup.sh runs)
if [[ -f "$SYSTEM_DIR/setup/lib/profiles.sh" ]]; then
  source "$SYSTEM_DIR/setup/lib/profiles.sh"
  _PROFILES_LOADED=true
fi

# Hostname configuration (set by argument parsing or auto-detection)
HOSTNAME_OVERRIDE=""
MACHINE_HOSTNAME=""

# Detect Homebrew prefix based on architecture
detect_homebrew_prefix() {
  if [[ -d "/opt/homebrew" ]]; then
    echo "/opt/homebrew" # Apple Silicon
  else
    echo "/usr/local" # Intel
  fi
}

get_fish_path() {
  echo "$(detect_homebrew_prefix)/bin/fish"
}

# =============================================================================
# Hostname Detection
# =============================================================================

# Detect and validate hostname
# Sets global MACHINE_HOSTNAME variable
detect_and_validate_hostname() {
  if [[ -n "$HOSTNAME_OVERRIDE" ]]; then
    # Hostname override provided, must validate it
    if ! is_known_hostname "$HOSTNAME_OVERRIDE"; then
      print_error "Unknown hostname: $HOSTNAME_OVERRIDE"
      print_info "Known hosts: $(get_known_hosts --csv)"
      exit 1
    fi
    MACHINE_HOSTNAME="$HOSTNAME_OVERRIDE"
    print_status "Machine: $MACHINE_HOSTNAME (overridden)"
  else
    # Auto-detect from hostname
    MACHINE_HOSTNAME=$(hostname -s)

    if ! is_known_hostname "$MACHINE_HOSTNAME"; then
      # Non-interactive mode
      if [[ ! -t 3 ]]; then
        print_error "Unknown hostname: $MACHINE_HOSTNAME"
        print_info "Known hosts: $(get_known_hosts --csv)"
        print_info "Override with: ./setup.sh --hostname <name>"
        exit 1
      fi

      print_warning "Unknown hostname: $MACHINE_HOSTNAME"
      read -p "  Set up this machine under an existing hostname? (y/n) " -n 1 -r <&3
      echo ""

      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Override with: ./setup.sh --hostname <name>"
        exit 1
      fi

      # Build hostname list
      local hosts=()
      while IFS= read -r host; do
        hosts+=("$host")
      done < <(get_known_hosts)

      echo ""
      print_info "Select a hostname for this machine:"
      local i
      for i in "${!hosts[@]}"; do
        echo "  $((i + 1))) ${hosts[$i]}"
      done
      echo "  $((${#hosts[@]} + 1))) Cancel"
      echo ""

      local choice
      read -r -p "  Enter selection [1-$((${#hosts[@]} + 1))]: " choice <&3

      if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#hosts[@]} + 1)); then
        print_error "Invalid selection"
        exit 1
      fi

      if ((choice == ${#hosts[@]} + 1)); then
        exit 1
      fi

      local selected="${hosts[$((choice - 1))]}"

      print_info "Setting hostname to $selected (requires sudo)..."
      sudo scutil --set ComputerName "$selected"
      sudo scutil --set HostName "$selected"
      sudo scutil --set LocalHostName "$selected"
      MACHINE_HOSTNAME="$selected"
      print_status "Machine: $MACHINE_HOSTNAME (configured)"
    else
      print_status "Machine: $MACHINE_HOSTNAME (detected)"
    fi
  fi

  # Export for child scripts
  export MACHINE_HOSTNAME
}

# Preprocess files with machine markers, e.g. `// @machine:Naomi-Klein-MacBook-Pro` / `// @end:Naomi-Klein-MacBook-Pro`
# (JSONC) or `# @machine:Naomi-Klein-MacBook-Pro` / `# @end:Naomi-Klein-MacBook-Pro` (TOML / shell).
# Tags accept hostnames or group names (laptop, work, server, ...).
#
# Filters the input by the current machine's group membership and writes the
# result to <output>. Non-marker comments are preserved; format-specific
# cleanup (e.g. JSON validation) is the caller's responsibility.
#
# Usage: preprocess_machine_markers <input> <output> [<comment_prefix>]
#   comment_prefix defaults to "//"
preprocess_machine_markers() {
  local input="$1"
  local output="$2"
  local comment_prefix="${3:-//}"
  local groups
  groups=$(get_machine_groups "$MACHINE_HOSTNAME")

  # Escape regex specials so prefixes like "//" are matched literally
  local re_prefix
  re_prefix=$(printf '%s' "$comment_prefix" | sed 's/[]\/$*.^|[\\]/\\&/g')

  awk -v groups=" $groups " -v prefix="$re_prefix" '
        $0 ~ ("^[[:space:]]*" prefix " @machine:") {
            tag = $0
            sub(/.*@machine:/, "", tag)
            sub(/[[:space:]].*/, "", tag)
            if (index(groups, " " tag " ") == 0) skip=1
            next
        }
        $0 ~ ("^[[:space:]]*" prefix " @end:") { skip=0; next }
        skip==0 { print }
    ' "$input" >"$output"
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
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty

  # Add Homebrew to PATH for this session
  local prefix
  prefix=$(detect_homebrew_prefix)
  eval "$("$prefix"/bin/brew shellenv)"

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
    print_warning "1Password CLI not installed. Required for git identity and secrets"
    return 1
  fi

  if op vault list --account my.1password.com &>/dev/null </dev/null; then
    print_status "1Password: authenticated"
    return 0
  fi

  echo ""
  print_warning "1Password authentication required for git identity and secrets"

  # Detect missing CLI integration
  if pgrep -q "1Password" && [[ ! -S ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ]]; then
    print_warning "1Password app is running but CLI integration is not enabled"
    print_info "Enable it: 1Password > Settings > Developer > 'Integrate with 1Password CLI'"
  fi

  # Skip prompt in non-interactive mode
  if [[ ! -t 3 ]]; then
    print_info "Non-interactive mode: skipping 1Password sign-in"
    print_info "Run 'op signin' and then 'secrets' later"
    return 1
  fi

  read -p "Press Enter to retry after signing in (or 'skip' to continue without secrets): " -r <&3
  if [[ "$REPLY" == "skip" ]]; then
    print_info "Skipping 1Password authentication"
    return 1
  fi

  # Re-check after user signs in via system prompt
  if op vault list --account my.1password.com &>/dev/null </dev/null; then
    print_status "1Password: authenticated"
    return 0
  fi

  print_error "1Password still not authenticated"
  print_info "Run 'secrets' after signing in to 1Password"
  return 1
}

inject_secrets() {
  if ! ensure_1password_auth; then
    echo ""
    print_warning "Secrets not injected. The following require manual setup:"
    print_warning "  • Git identity (~/.gitconfig)"
    print_warning "  • LaunchAgents (display monitor, spotlight shortcuts)"
    print_warning "  Run 'secrets' after signing in to 1Password"
    echo ""
    return 0
  fi

  print_info "Injecting secrets from 1Password..."
  if [[ -x "$SYSTEM_DIR/setup/secrets.sh" ]]; then
    "$SYSTEM_DIR/setup/secrets.sh"
  else
    bash "$SYSTEM_DIR/setup/secrets.sh"
  fi
}

# Refresh global Claude instructions from 1Password (subset of inject_secrets,
# safe to call from --brew and --macos paths)
refresh_claude_global() {
  if ! ensure_1password_auth; then
    print_warning "CLAUDE.global.md not refreshed (1Password unavailable)"
    return 0
  fi
  bash "$SYSTEM_DIR/setup/secrets.sh" --claude-global
}

# =============================================================================
# Homebrew Sync (Declarative)
# =============================================================================

prepare_brewfile() {
  # Generate machines/<hostname>/Brewfile by concatenating all label Brewfiles
  # the machine belongs to. This file is the sole input to `brew bundle` and
  # is gitignored (see .gitignore) — labels/ is the source of truth.
  local machine_dir="$SYSTEM_DIR/profiles/machines/$MACHINE_HOSTNAME"
  local combined="$machine_dir/Brewfile"
  mkdir -p "$machine_dir"

  local groups
  groups=$(get_machine_groups "$MACHINE_HOSTNAME")

  {
    echo "# GENERATED by setup.sh from .system/profiles/labels/ — do not edit."
    echo "# Machine: $MACHINE_HOSTNAME  Groups: $groups"
    echo ""
  } >"$combined"

  # get_machine_groups appends the hostname as a trailing "group"; skip it
  # since there's no labels/<hostname>/ directory.
  for group in $groups; do
    [[ "$group" == "$MACHINE_HOSTNAME" ]] && continue
    local label_brewfile="$SYSTEM_DIR/profiles/labels/$group/Brewfile"
    if [[ -f "$label_brewfile" ]]; then
      {
        echo "# ---- labels/$group ----"
        cat "$label_brewfile"
        echo ""
      } >>"$combined"
    fi
  done

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

    # Check if remote is reachable
    if git -C "$(brew --repository "$tap")" ls-remote origin HEAD &>/dev/null; then
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

# Normalize tap name by stripping homebrew- prefix from repo portion
# e.g., "pinginc/homebrew-lrl" → "pinginc/lrl"
normalize_tap_name() {
  echo "${1/homebrew-/}"
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
  done <"$brewfile"

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
    local normalized_installed
    normalized_installed=$(normalize_tap_name "$installed_tap")
    for declared_tap in "${declared_taps[@]}"; do
      if [[ "$normalized_installed" == "$(normalize_tap_name "$declared_tap")" ]]; then
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
  print_header "Syncing Homebrew Packages ($MACHINE_HOSTNAME)"

  # Set GitHub token for private Homebrew taps (work group only)
  if is_machine_in_group "$MACHINE_HOSTNAME" "work" && command -v op &>/dev/null && op vault list --account my.1password.com &>/dev/null </dev/null; then
    local gh_token
    if gh_token=$(op read "op://Private/Github Token/password" --account my.1password.com 2>/dev/null); then
      export HOMEBREW_GITHUB_API_TOKEN="$gh_token"
      print_status "GitHub API token configured for Homebrew"
    fi
  fi

  # Generate machines/<host>/Brewfile from labels
  local brewfile
  brewfile=$(prepare_brewfile)
  print_info "Generated: ${brewfile#"$DOTFILES/"}"

  # Clean up broken and undeclared taps before updating
  check_and_remove_broken_taps
  cleanup_undeclared_taps "$brewfile"

  # Show warning about cleanup
  echo ""
  print_warning "Homebrew will install packages from Brewfile and remove unlisted packages"
  print_info "Packages not in Brewfile will be uninstalled (--force-cleanup)"
  echo ""

  # Update and sync (brew bundle handles taps + mas apps natively in a single pass)
  print_info "Updating Homebrew..."
  brew update

  print_info "Installing packages and cleaning up..."
  if brew bundle --file="$brewfile" --force-cleanup --verbose; then
    print_status "Homebrew packages synced"
  else
    print_warning "Some packages may have failed to install"
  fi
}

# =============================================================================
# Shell & Environment Setup
# =============================================================================

sync_theme() {
  if [[ -x "$SYSTEM_DIR/setup/sync-theme.sh" ]]; then
    "$SYSTEM_DIR/setup/sync-theme.sh"
  elif [[ -f "$SYSTEM_DIR/setup/sync-theme.sh" ]]; then
    bash "$SYSTEM_DIR/setup/sync-theme.sh"
  else
    print_warning "sync-theme.sh not found, skipping theme sync"
  fi
}

configure_claude() {
  local base="$DOTFILES/claude/settings.jsonc"
  local output="$DOTFILES/claude/settings.json"

  if [[ ! -f "$base" ]]; then
    print_warning "Claude settings source not found, skipping"
    return 0
  fi

  if ! command -v jq &>/dev/null; then
    print_warning "jq not installed, copying Claude settings as-is"
    # literal $HOME must reach envsubst
    # shellcheck disable=SC2016
    grep -v '^\s*//' "$base" | envsubst '$HOME' >"$output"
    return 0
  fi

  local tmp="${output}.tmp"
  preprocess_machine_markers "$base" "$tmp" "//"
  # Strip trailing commas, drop comments via jq, then expand $HOME.
  # shellcheck disable=SC2016
  sed -E 's/,([[:space:]]*[]{}])/\1/g' "$tmp" | jq . | envsubst '$HOME' >"$output"
  rm -f "$tmp"
  print_status "Claude settings: configured ($MACHINE_HOSTNAME)"
}

configure_codex() {
  local base="$DOTFILES/codex/config.source.toml"
  local output="$DOTFILES/codex/config.toml"

  if [[ ! -f "$base" ]]; then
    print_warning "Codex config source not found, skipping"
    return 0
  fi

  local tmp="${output}.tmp"
  preprocess_machine_markers "$base" "$tmp" "#"
  # TOML keeps non-marker comments; just expand $HOME if any.
  # shellcheck disable=SC2016
  envsubst '$HOME' <"$tmp" >"$output"
  rm -f "$tmp"
  chmod 600 "$output"
  print_status "Codex config: configured ($MACHINE_HOSTNAME)"
}

install_claude_code() {
  export CLAUDE_CONFIG_DIR="$HOME/.config/claude"

  # Remove legacy homebrew cask if it's still around (we've moved to the native installer).
  if brew list --cask claude-code &>/dev/null; then
    print_info "Removing legacy Homebrew claude-code cask..."
    brew uninstall --cask claude-code &>/dev/null || true
    # Clear stale symlink so the curl installer can take over the path.
    rm -f "$HOME/.local/bin/claude" 2>/dev/null || true
  fi

  local claude_bin="$HOME/.local/bin/claude"
  if [[ -x "$claude_bin" ]]; then
    print_info "Updating Claude Code..."
    "$claude_bin" update &>/dev/null || true
    print_status "Claude Code: $("$claude_bin" --version 2>/dev/null || echo installed)"
    update_claude_plugins
    return 0
  fi

  print_info "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | sh
  print_status "Claude Code: installed"
  update_claude_plugins
}

update_claude_plugins() {
  local claude_bin="$HOME/.local/bin/claude"
  [[ -x "$claude_bin" ]] || return 0
  if ! command -v jq >/dev/null 2>&1; then
    print_warning "jq not found; skipping Claude plugin updates"
    return 0
  fi

  print_info "Refreshing Claude plugin marketplaces..."
  "$claude_bin" plugin marketplace update >/dev/null 2>&1 || true

  # Register and install local dotfiles plugins (idempotent)
  local local_mkt="$DOTFILES/claude/local-plugins"
  if [[ -d "$local_mkt" ]]; then
    "$claude_bin" plugin marketplace list 2>/dev/null | grep -q "dotfiles" ||
      "$claude_bin" plugin marketplace add "$local_mkt" >/dev/null 2>&1 || true
    "$claude_bin" plugin list 2>/dev/null | grep -q "basedpyright-lsp@dotfiles" ||
      "$claude_bin" plugin install basedpyright-lsp@dotfiles --scope user >/dev/null 2>&1 || true
  fi

  local ids
  ids=$("$claude_bin" plugin list --json 2>/dev/null |
    jq -r '.[] | select(.scope == "user") | .id')

  if [[ -z "$ids" ]]; then
    print_status "Claude plugins: none installed yet"
    return 0
  fi

  local count=0
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    "$claude_bin" plugin update "$id" >/dev/null 2>&1 || true
    count=$((count + 1))
  done <<<"$ids"
  print_status "Claude plugins: updated $count plugin(s) (restart to apply)"
}

create_symlinks() {
  print_info "Creating symlinks..."
  if [[ -x "$SYSTEM_DIR/setup/symlinks.sh" ]]; then
    source "$SYSTEM_DIR/setup/symlinks.sh"
  else
    bash "$SYSTEM_DIR/setup/symlinks.sh"
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
    print_warning "Sketchybar not installed, skipping"
    return 0
  fi

  # Make sure scripts are executable
  if [[ -d "$DOTFILES/sketchybar" ]]; then
    chmod +x "$DOTFILES/sketchybar/sketchybarrc" 2>/dev/null || true
    chmod +x "$DOTFILES/sketchybar/plugins/"*.sh 2>/dev/null || true
    chmod +x "$DOTFILES/sketchybar/items/"*.sh 2>/dev/null || true
  fi

  local plist="$HOME/Library/LaunchAgents/com.felixkratz.sketchybar.plist"
  # `brew services start sketchybar` writes this competing LaunchAgent. If
  # both are loaded, the homebrew one wins the Mach port and our configured
  # agent silently exits with code 1. Remove it so our plist is authoritative.
  local stale_plist="$HOME/Library/LaunchAgents/homebrew.mxcl.sketchybar.plist"
  if [[ -f "$stale_plist" ]]; then
    launchctl unload "$stale_plist" 2>/dev/null || true
    rm -f "$stale_plist"
    print_info "Removed stale homebrew.mxcl.sketchybar LaunchAgent"
  fi

  # Load the LaunchAgent (generated by secrets.sh)
  if [[ -f "$plist" ]]; then
    # Unload first if already loaded, then reload
    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
    print_status "Sketchybar: loaded (starts at login)"
  else
    print_warning "Sketchybar plist not found, run secrets first"
  fi
}

setup_display_monitor() {
  if ! command -v aerospace &>/dev/null || ! command -v sketchybar &>/dev/null; then
    print_warning "Aerospace or Sketchybar not installed, skipping display monitor"
    return 0
  fi

  # Make scripts executable
  chmod +x "$SYSTEM_DIR/setup/monitor-watcher.sh" 2>/dev/null || true
  chmod +x "$SYSTEM_DIR/setup/reload-display-config.sh" 2>/dev/null || true
  chmod +x "$SYSTEM_DIR/setup/display-profiles.sh" 2>/dev/null || true

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
    print_warning "Display monitor plist not found, run 'secrets' first"
  fi

  # Apply display profile now (the watcher only triggers on count changes)
  if command -v displayplacer &>/dev/null; then
    print_info "Applying display profile..."
    bash "$SYSTEM_DIR/setup/display-profiles.sh"
  fi
}

setup_spotlight_shortcuts() {
  # Make script executable
  chmod +x "$SYSTEM_DIR/setup/disable-spotlight-shortcuts.sh" 2>/dev/null || true

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
    print_warning "Spotlight shortcuts plist not found, run 'secrets' first"
  fi
}

setup_wallpaper() {
  local theme_file="$SYSTEM_DIR/themes/theme.toml"
  if [[ ! -f "$theme_file" ]]; then
    print_warning "Theme file not found, skipping wallpaper"
    return 0
  fi

  local flavor
  flavor=$(grep '^flavor *= *"' "$theme_file" | head -1 | sed 's/.*= *"\([^"]*\)".*/\1/')
  local wallpaper_dir="$SYSTEM_DIR/themes/catppuccin-${flavor}/wallpapers"

  if [[ ! -d "$wallpaper_dir" ]]; then
    return 0
  fi

  local wallpapers=()
  while IFS= read -r -d '' f; do
    wallpapers+=("$f")
  done < <(find "$wallpaper_dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0 | sort -z)

  if [[ ${#wallpapers[@]} -eq 0 ]]; then
    return 0
  fi

  local wallpaper
  if [[ ${#wallpapers[@]} -eq 1 ]]; then
    wallpaper="${wallpapers[0]}"
  else
    print_info "Available wallpapers:"
    for i in "${!wallpapers[@]}"; do
      echo "  $((i + 1))) $(basename "${wallpapers[$i]}")"
    done
    local choice
    read -rp "Select wallpaper [1-${#wallpapers[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#wallpapers[@]})); then
      wallpaper="${wallpapers[$((choice - 1))]}"
    else
      print_warning "Invalid selection, skipping wallpaper"
      return 0
    fi
  fi

  print_info "Setting wallpaper..."
  osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$wallpaper\""
  print_status "Wallpaper: $(basename "$wallpaper") applied to all desktops"
}

setup_docker() {
  local docker_dir="$HOME/.docker"
  local config_file="$docker_dir/config.json"
  local plugins_dir="/opt/homebrew/lib/docker/cli-plugins"

  mkdir -p "$docker_dir"

  if [[ -f "$config_file" ]]; then
    local tmp
    tmp=$(jq --arg dir "$plugins_dir" \
      '.cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) + [$dir] | unique)' \
      "$config_file")
    echo "$tmp" >"$config_file"
  else
    jq -n --arg dir "$plugins_dir" \
      '{"cliPluginsExtraDirs": [$dir]}' >"$config_file"
  fi
  print_status "Docker: CLI plugins directory configured"
}

setup_default_browser() {
  # Only set default browser if Waterfox is installed (which happens during brew sync)
  if [[ ! -d "/Applications/Waterfox.app" ]]; then
    print_warning "Waterfox not installed, skipping browser setup"
    return 0
  fi

  # Check if defaultbrowser is available
  if ! command -v defaultbrowser &>/dev/null; then
    print_warning "defaultbrowser command not found, skipping default browser setup"
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
  if [[ ! -f "$SYSTEM_DIR/macos/.macos" ]]; then
    print_error "macOS preferences file not found: $SYSTEM_DIR/macos/.macos"
    return 1
  fi

  print_info "Applying macOS preferences..."
  source "$SYSTEM_DIR/macos/.macos"
  print_status "macOS preferences applied"
}

# Open /dev/tty on fd 3 for interactive prompts (preserves pipe on fd 0).
# bash reports exec-redirect failures to its own stderr *before* the
# redirect applies, so a flat `2>/dev/null` on the exec leaks the error.
# Wrap in a block redirect to reliably swallow it when /dev/tty is absent.
setup_interactive_fd() {
  if [[ -t 0 ]]; then
    exec 3<&0
    return
  fi
  if { exec 3</dev/tty; } 2>/dev/null; then
    return
  fi
  exec 3<&0
}

# =============================================================================
# Workflow Functions
# =============================================================================

# Shared bootstrap: profiles, hostname, working directory. Safe to call from
# any entry point (run_setup / run_brew / run_macos).
bootstrap_common() {
  ensure_profiles_loaded
  setup_interactive_fd
  detect_and_validate_hostname
  cd "$DOTFILES"
}

# Homebrew sync + post-brew install tasks that depend on brew-installed tools.
# Shared between run_setup and run_brew so --brew stays a true subset of setup.
homebrew_phase() {
  run_brew_sync
  install_claude_code
  setup_docker
  setup_default_browser
}

run_setup() {
  print_header "Dotfiles Setup"

  # Prerequisites (must run before hostname detection for fresh installs)
  ensure_xcode_clt
  ensure_homebrew
  ensure_dotfiles

  bootstrap_common

  # Apply macOS preferences first (includes Full Disk Access check for terminal)
  # This must run before Homebrew sync to ensure terminal has required permissions
  apply_macos_defaults

  inject_secrets

  homebrew_phase

  # Sync theme colors to all tool configs
  sync_theme

  # Generate Claude settings based on hostname
  configure_claude

  # Generate Codex config based on hostname
  configure_codex

  # Shell and environment
  create_symlinks
  setup_fish_shell
  setup_fisher
  setup_tmux_plugins
  setup_sketchybar
  setup_display_monitor
  setup_spotlight_shortcuts

  # Configure remote access tools (server machines)
  if is_machine_in_group "$MACHINE_HOSTNAME" "server"; then
    source "$DOTFILES/.system/setup/rustdesk.sh"
    source "$DOTFILES/.system/setup/tailscale.sh"
  fi

  # Set wallpaper
  setup_wallpaper

  # Reload window manager configs
  if command -v aerospace &>/dev/null; then
    if pgrep -q AeroSpace; then
      aerospace reload-config 2>/dev/null || true
      print_status "Aerospace: config reloaded"
    else
      open -a AeroSpace
      print_status "Aerospace: launched"
    fi
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
  local next_step=3
  if command -v gh &>/dev/null && ! gh auth status &>/dev/null; then
    echo "  ${next_step}. Authenticate GitHub CLI: gh auth login"
    next_step=$((next_step + 1))
  fi
  if ! command -v op &>/dev/null || ! op vault list --account my.1password.com &>/dev/null </dev/null; then
    echo "  ${next_step}. Set up secrets from 1Password:"
    echo "     - Sign in: op signin"
    echo "     - Run: secrets"
  fi
  echo ""
}

run_brew() {
  print_header "Homebrew Sync"

  bootstrap_common

  # Prompt for 1Password sign-in if needed (GitHub token for private taps)
  if is_machine_in_group "$MACHINE_HOSTNAME" "work" && command -v op &>/dev/null; then
    if ! op vault list --account my.1password.com &>/dev/null </dev/null; then
      if [[ -t 3 ]]; then
        echo ""
        read -p "Sign in to 1Password for private tap access? (y/n) " -n 1 -r <&3
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          eval "$(op signin 2>/dev/null)" || true
        fi
      fi
    fi
  fi

  refresh_claude_global

  homebrew_phase

  print_header "Homebrew Sync Complete!"
}

run_macos() {
  print_header "macOS Preferences"

  bootstrap_common

  apply_macos_defaults

  refresh_claude_global

  print_header "macOS Preferences Applied!"
  echo "Note: Some changes require a logout/restart to take effect."
  echo ""
}

show_help() {
  cat <<'EOF'
Dotfiles Setup Script (Idempotent, Multi-Machine)

Usage:
  ./setup.sh                        Run full setup (auto-detect hostname)
  ./setup.sh --hostname <hostname>  Override hostname
  ./setup.sh --brew                 Sync Homebrew packages only
  ./setup.sh --macos                Apply macOS preferences only
  ./setup.sh --help                 Show this help message

EOF

  # Dynamic machine listing
  echo "Machines:"
  echo "  Hostname is auto-detected. Each machine gets specific brew groups:"
  if [[ "$_PROFILES_LOADED" == "true" ]]; then
    while IFS= read -r host; do
      local groups
      groups=$(get_machine_groups "$host")
      printf '    %-8s (%s)\n' "$host" "$groups"
    done < <(get_known_hosts)
  else
    echo "    (Run from dotfiles directory to see machine list)"
  fi
  echo ""
  echo "  Use --hostname to override: ./setup.sh --hostname <name>"

  cat <<'EOF'

Full Setup:
  Runs all setup tasks idempotently:
  - Installs Xcode CLT and Homebrew (if missing)
  - Clones dotfiles repository (if missing)
  - Injects secrets from 1Password (work group machines)
  - Syncs Homebrew packages (declarative with --force-cleanup)
  - Creates symlinks
  - Configures Fish shell as default
  - Installs Fisher and TPM
  - Applies macOS system preferences

Homebrew Sync (--brew):
  Generates .system/profiles/machines/<hostname>/Brewfile by concatenating
  the label Brewfiles for the host's groups (labels/ is the sole source of
  truth), then runs brew bundle --force-cleanup to install packages and remove
  unlisted ones.

macOS Preferences (--macos):
  Applies system preferences: UI, input, sound, Finder, screenshots, etc.

1Password Integration (work group machines):
  Private Homebrew taps require a GitHub token from 1Password.
  The script will prompt to sign in if needed, or you can skip.

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
    --hostname | -n)
      shift
      if [[ $# -eq 0 ]]; then
        local hosts_hint=""
        if [[ "$_PROFILES_LOADED" == "true" ]]; then
          hosts_hint=" ($(get_known_hosts --csv))"
        fi
        print_error "--hostname requires a value${hosts_hint}"
        exit 1
      fi
      HOSTNAME_OVERRIDE="$1"
      ;;
    --brew | -b)
      mode="brew"
      ;;
    --macos | -m)
      mode="macos"
      ;;
    --help | -h)
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
