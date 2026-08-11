#!/usr/bin/env bash
#
# Manage secrets using 1Password CLI
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

  if ! op vault list --account "$OP_PERSONAL_ACCOUNT" &>/dev/null </dev/null; then
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

  # Staged through a temp file so a failed injection (renamed 1Password item,
  # revoked session) leaves the previous credential intact rather than
  # truncating it. mktemp is 0600, and the umask covers the envsubst pass, so
  # the value is never briefly world-readable either.
  local staged
  staged=$(mktemp)

  local op_args=(-f -i "$template" -o "$staged")
  if [[ -n "$account" ]]; then
    op_args+=(--account "$account")
  fi

  if (
    umask 077
    op inject "${op_args[@]}" || exit 1
    # shellcheck disable=SC2016
    envsubst '$HOME' <"$staged" >"${staged}.env" && mv "${staged}.env" "$staged"
  ); then
    mkdir -p "$(dirname "$output")"
    mv "$staged" "$output"
    chmod 600 "$output"
    print_status "$description configured"
  else
    rm -f "$staged" "${staged}.env"
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

  # Check if already logged in (username present in status output)
  if atuin status 2>/dev/null | grep -q "^Username:"; then
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

  # These land on argv and are briefly visible in ps. `atuin login` offers no
  # stdin or key-file input, so this is unavoidable; it only runs on a machine
  # that is not already logged in (guarded by the atuin status check above).
  if atuin login -u "$username" -p "$password" -k "$key" 2>/dev/null; then
    print_status "Atuin sync configured"
    # Trigger initial sync
    atuin sync 2>/dev/null || true
  else
    print_error "Failed to login to Atuin"
    return 1
  fi
}

# Sync one 1Password document to a local file, resolving drift in both
# directions.
#
# Every caller previously carried its own copy of this diff-and-prompt block.
# The `l | L | *)` bug, where a bare Enter silently overwrote the remote
# document, existed in two of those copies independently, so the semantics live
# in one place now and .system/tests/test-secrets-invariants.sh pins them.
#
# Usage: sync_op_document <doc_title> <output_file> <label> <account>
# Returns 1 only when the document does not exist in 1Password.
sync_op_document() {
  local doc_title="$1"
  local output_file="$2"
  local label="$3"
  local account="$4"
  local temp_file err choice

  temp_file=$(mktemp)

  # --force avoids op's own overwrite prompt
  if ! op document get "$doc_title" --output "$temp_file" --force --account "$account" 2>/dev/null; then
    rm -f "$temp_file"
    print_warning "  $label not found in 1Password (document: $doc_title)"
    return 1
  fi

  mkdir -p "$(dirname "$output_file")"

  if [[ ! -f "$output_file" ]]; then
    mv "$temp_file" "$output_file"
    chmod 600 "$output_file"
    print_status "  $label retrieved (new)"
    return 0
  fi

  if diff -q "$output_file" "$temp_file" >/dev/null 2>&1; then
    rm -f "$temp_file"
    print_status "  $label unchanged"
    return 0
  fi

  echo ""
  print_warning "$label has changed:"
  echo "─────────────────────────────────────────"
  diff --color=auto -u "$output_file" "$temp_file" | head -50 || true
  echo "─────────────────────────────────────────"
  echo ""
  echo "Choose action:"
  echo "  [l] Keep local version and push it to 1Password (overwrites remote)"
  echo "  [r] Use remote (1Password) version (overwrites local)"
  echo "  [anything else] Keep local, change nothing"
  echo ""
  read -rp "Action [l/r]: " choice

  case "$choice" in
  r | R)
    mv "$temp_file" "$output_file"
    chmod 600 "$output_file"
    print_status "  $label updated from 1Password"
    ;;
  l | L)
    rm -f "$temp_file"
    if err=$(op document edit "$doc_title" "$output_file" --account "$account" 2>&1); then
      print_status "  $label: local version pushed to 1Password"
    else
      print_warning "  $label: kept local (failed to push to 1Password)"
      printf '%s\n' "$err" | sed 's/^/      /'
    fi
    ;;
  *)
    rm -f "$temp_file"
    print_warning "  $label: no choice made, kept local and pushed nothing"
    ;;
  esac
}

# Retrieve work-specific Claude skills from 1Password
inject_claude_skills() {
  local CLAUDE_SKILLS_OUTPUT="$SENSITIVE_DIR/claude-skills"

  echo "  Retrieving work-specific Claude skills from 1Password..."

  # skill_name:doc_title pairs
  local work_skills="argocd:claude-skill-argocd astro:claude-skill-astro aws:claude-skill-aws lrl-cli:claude-skill-lrl-cli observe:claude-skill-observe signadot:claude-skill-signadot spacectl:claude-skill-spacectl prod-release:claude-skill-prod-release prod-version:claude-skill-prod-version"

  for pair in $work_skills; do
    local skill_name="${pair%%:*}"
    local doc_title="${pair#*:}"
    local output_dir="$CLAUDE_SKILLS_OUTPUT/$skill_name"

    mkdir -p "$output_dir"
    chmod 700 "$output_dir"

    sync_op_document "$doc_title" "$output_dir/SKILL.md" \
      "$skill_name skill" "$OP_WORK_ACCOUNT" || true
  done
}

# Retrieve work-specific Claude rules from 1Password.
#
# Rules load as global instructions in every session, so unlike a skill they are
# always in context. They live in 1Password rather than the repo when their
# content is work-specific: pr-lint names real ticket prefixes and internal
# service names, and this repo is public.
inject_claude_rules() {
  local CLAUDE_RULES_OUTPUT="$SENSITIVE_DIR/claude-rules"

  echo "  Retrieving work-specific Claude rules from 1Password..."

  # rule_name:doc_title pairs
  local work_rules="pr-lint:claude-rule-pr-lint"

  mkdir -p "$CLAUDE_RULES_OUTPUT"
  chmod 700 "$CLAUDE_RULES_OUTPUT"

  for pair in $work_rules; do
    local rule_name="${pair%%:*}"
    local doc_title="${pair#*:}"

    sync_op_document "$doc_title" "$CLAUDE_RULES_OUTPUT/$rule_name.md" \
      "$rule_name rule" "$OP_WORK_ACCOUNT" || true
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

  # Extract into a sibling staging dir and swap, so a failed tar cannot destroy
  # the existing skill. Sibling, not $TMPDIR, keeps the swap on one filesystem.
  local staging="${output_dir}.incoming"
  rm -rf "$staging"
  mkdir -p "$staging"
  chmod 700 "$staging"

  if ! tar xf "$temp_file" -C "$staging" 2>/dev/null; then
    rm -rf "$staging"
    rm -f "$temp_file"
    print_error "  Failed to extract $skill_name skill archive"
    return 1
  fi

  find "$staging" -type d -exec chmod 700 {} \;
  find "$staging" -type f -exec chmod 600 {} \;

  rm -rf "$output_dir"
  mv "$staging" "$output_dir"
  rm -f "$temp_file"
  print_status "  $skill_name skill archive extracted"
}

# Retrieve global Claude instructions from 1Password
inject_claude_global() {
  sync_op_document "claude-global-instructions" \
    "$SENSITIVE_DIR/CLAUDE.global.md" "CLAUDE.global.md" "$OP_PERSONAL_ACCOUNT"
}

# Materialize ~/.aws/config from 1Password.
#
# Bidirectional like inject_claude_global, because the file is hand-maintained:
# its comment header records the dev-admin/prod-readonly asymmetry, the reason
# the SSO session must stay named "laurel", and the `lrl init --force` hazard.
# `lrl init` strips those comments, so local edits have to be able to win.
inject_aws_config() {
  local doc_title="aws-config"
  local output_file="$HOME/.aws/config"

  mkdir -p "$HOME/.aws"
  chmod 700 "$HOME/.aws"

  if sync_op_document "$doc_title" "$output_file" "AWS config" "$OP_WORK_ACCOUNT"; then
    return 0
  fi

  # Only reachable when the document is absent. Worth spelling out, because
  # until it is seeded the local file is the single copy of a hand-built config.
  if [[ -f "$output_file" ]]; then
    print_info "    $output_file is currently the only copy. Seed 1Password with:"
    print_info "    op document create \"$output_file\" --title $doc_title --vault Employee --account \"\$OP_WORK_ACCOUNT\""
  fi
  return 1
}

read_work_account() {
  op read "op://Private/1password-work-account/domain" --account "$OP_PERSONAL_ACCOUNT"
}

inject_spacelift() {
  local account="$1"
  local key_id key_secret token

  if [[ -f "$TEMPLATES_DIR/spacelift-api-key.tpl" ]]; then
    inject_template "$TEMPLATES_DIR/spacelift-api-key.tpl" \
      "$SENSITIVE_DIR/spacelift-api-key.fish" "Spacelift API key" "$account"
  fi

  if [[ -f "$TEMPLATES_DIR/spacelift-profile.json.tpl" ]]; then
    inject_template "$TEMPLATES_DIR/spacelift-profile.json.tpl" \
      "$HOME/.spacelift/config.json" "Spacelift spacectl profile" "$account"
  fi

  echo "  Injecting Spacelift registry token..."

  key_id=$(op read --account "$account" "op://Employee/spacelift-api-key/api_key_id") || {
    print_error "Failed to read Spacelift API key ID"
    return 1
  }
  key_secret=$(op read --account "$account" "op://Employee/spacelift-api-key/api_key_secret") || {
    print_error "Failed to read Spacelift API key secret"
    return 1
  }

  token=$(printf 'api:%s:%s' "$key_id" "$key_secret" | base64 | tr -d '\n=')

  mkdir -p "$HOME/.terraform.d"
  chmod 700 "$HOME/.terraform.d"
  (
    umask 077
    printf '{\n  "credentials": {\n    "spacelift.io": {\n      "token": "%s"\n    }\n  }\n}\n' \
      "$token" >"$HOME/.terraform.d/credentials.tfrc.json"
  )
  chmod 600 "$HOME/.terraform.d/credentials.tfrc.json"
  print_status "Spacelift registry token configured"
}

# Check which secrets are configured
check_secrets() {
  echo ""
  echo "Checking secrets configuration ($MACHINE_HOSTNAME)..."
  echo ""

  local all_configured=true

  # Check GitHub hosts (optional, gh auth login is preferred)
  if [[ -f "$HOME/.config/gh/hosts.yml" ]]; then
    print_status "GitHub CLI: configured"
  else
    print_warning "GitHub CLI: not configured (run 'gh auth login')"
  fi

  # Work-only secrets (work group machines)
  if is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
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

    if [[ -f "$SENSITIVE_DIR/spacelift-api-key.fish" ]]; then
      print_status "Spacelift API key: configured"
    else
      print_warning "Spacelift API key: not configured"
      all_configured=false
    fi

    if [[ -f "$HOME/.spacelift/config.json" ]]; then
      print_status "Spacelift spacectl profile: configured"
    else
      print_warning "Spacelift spacectl profile: not configured"
      all_configured=false
    fi

    if grep -q '"spacelift.io"' "$HOME/.terraform.d/credentials.tfrc.json" 2>/dev/null; then
      print_status "Spacelift registry token: configured"
    else
      print_warning "Spacelift registry token: not configured"
      all_configured=false
    fi

    if [[ -f "$HOME/.aws/config" ]]; then
      local aws_profiles
      aws_profiles=$(grep -c '^\[profile ' "$HOME/.aws/config" 2>/dev/null || true)
      print_status "AWS config: configured (${aws_profiles:-0} named profiles)"
    else
      print_warning "AWS config: not configured"
      all_configured=false
    fi

    # For SSO there is no stored key, so expiry is the only thing that decides
    # whether any aws command works. Checked locally, no API call.
    local sso_expiry
    sso_expiry=$(jq -r 'select(.expiresAt) | .expiresAt' "$HOME"/.aws/sso/cache/*.json 2>/dev/null | sort -r | head -1)
    if [[ -n "$sso_expiry" ]]; then
      local norm expiry_epoch
      norm="${sso_expiry%Z}"
      norm="${norm%%.*}"
      expiry_epoch=$(date -u -j -f '%Y-%m-%dT%H:%M:%S' "$norm" +%s 2>/dev/null || echo 0)
      if [[ "$expiry_epoch" -gt "$(date -u +%s)" ]]; then
        print_status "AWS SSO session: valid until $sso_expiry"
      else
        print_warning "AWS SSO session: expired $sso_expiry (run 'aws sso login --sso-session laurel')"
      fi
    else
      print_warning "AWS SSO session: no cached token (run 'aws sso login --sso-session laurel')"
    fi

    if [[ -s "$SENSITIVE_DIR/context7-api-key" ]]; then
      print_status "Context7 API key: configured"
    else
      print_warning "Context7 API key: not configured"
      all_configured=false
    fi

    # Static file with no template by design; see CLAUDE.md. Checked here so a
    # missing or emptied file is visible rather than silently breaking the MCP.
    if [[ -f "$SENSITIVE_DIR/warpstream.fish" ]]; then
      local ws_missing=()
      for var in WARPSTREAM_API_KEY WARPSTREAM_AGENT_KEY WARPSTREAM_MCP_API_KEY; do
        grep -qE "^set -g[x]? $var " "$SENSITIVE_DIR/warpstream.fish" || ws_missing+=("$var")
      done
      if [[ ${#ws_missing[@]} -eq 0 ]]; then
        print_status "WarpStream keys: configured"
      else
        print_warning "WarpStream keys: missing ${ws_missing[*]}"
        all_configured=false
      fi
    else
      print_warning "WarpStream keys: not configured (rotate by editing warpstream.fish in place)"
      all_configured=false
    fi

    # Owned by `observe auth configure`, not by this script; reported so an
    # expired token shows up here instead of as an MCP 401.
    if jq -e '.profiles[.currentProfile] | select(.customerId and .token)' \
      "$HOME/.observe/config.json" >/dev/null 2>&1; then
      print_status "Observe token: configured"
    else
      print_warning "Observe token: not configured (run 'observe auth configure --token ...')"
      all_configured=false
    fi

    if [[ -d "$HOME/.signadot" ]]; then
      print_status "Signadot: authenticated"
    else
      print_warning "Signadot: not authenticated (run 'signadot auth login'; the MCP server shares this credential)"
    fi

    # Check work-specific Claude skills
    local work_skills=("argocd" "astro" "aws" "lrl-cli" "observe" "signadot" "spacectl" "prod-release" "prod-version" "notion-research-documentation")
    for skill in "${work_skills[@]}"; do
      if [[ -d "$DOTFILES/claude/skills/$skill" ]] || [[ -d "$SENSITIVE_DIR/claude-skills/$skill" ]]; then
        print_status "Claude skill: $skill configured"
      else
        print_warning "Claude skill: $skill not configured"
        all_configured=false
      fi
    done

    # Check work-specific Claude rules. Unlike skills these are always in
    # context, so a missing one silently removes a guardrail.
    local work_rules=("pr-lint")
    for rule in "${work_rules[@]}"; do
      if [[ -f "$SENSITIVE_DIR/claude-rules/$rule.md" ]]; then
        if [[ -L "$DOTFILES/claude/rules/$rule.md" ]]; then
          print_status "Claude rule: $rule configured"
        else
          print_warning "Claude rule: $rule retrieved but not linked (run symlinks.sh)"
          all_configured=false
        fi
      else
        print_warning "Claude rule: $rule not configured"
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
    print_info "$MACHINE_HOSTNAME: work-only secrets not checked"
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

    if [[ -f "$SENSITIVE_DIR/tailscale-tailnet" ]]; then
      print_status "Tailscale tailnet name: configured"
    else
      print_warning "Tailscale tailnet name: not configured"
      all_configured=false
    fi

    if [[ -f "$SENSITIVE_DIR/tailscale-authkey" ]]; then
      print_status "Tailscale OAuth client secret: configured"
    else
      print_warning "Tailscale OAuth client secret: not configured"
      all_configured=false
    fi
  fi

  # Check npm token
  if [[ -f "$SENSITIVE_DIR/.npmrc" ]]; then
    print_status "npm token: configured"
  else
    print_warning "npm token: not configured (run secrets to inject)"
    all_configured=false
  fi

  if is_machine_in_group "$MACHINE_HOSTNAME" "server"; then
    if [[ -f "$SENSITIVE_DIR/anthropic-api-key" ]]; then
      print_status "Anthropic API key: configured"
    else
      print_warning "Anthropic API key: not configured"
      all_configured=false
    fi

    if [[ -x "$SENSITIVE_DIR/claude-api-key-helper.sh" ]]; then
      print_status "Claude API key helper: configured"
    else
      print_warning "Claude API key helper: not configured"
      all_configured=false
    fi
  fi

  if [[ -f "$SENSITIVE_DIR/github-pat" ]]; then
    print_status "GitHub PAT: configured"
  else
    print_warning "GitHub PAT: not configured"
    all_configured=false
  fi

  # Check global Claude instructions
  if [[ -f "$SENSITIVE_DIR/CLAUDE.global.md" ]]; then
    print_status "CLAUDE.global.md: configured"
  else
    print_warning "CLAUDE.global.md: not configured"
    all_configured=false
  fi

  # Check Atuin sync status
  if command -v atuin &>/dev/null; then
    if atuin status 2>/dev/null | grep -q "^Username:"; then
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

  # An unknown hostname makes every is_machine_in_group test below fail, which
  # silently skips all work and server secrets. macOS reverts hostnames to the
  # Firstname-Lastname-Serial form after a Sharing or network change, so this is
  # a live failure mode and must be loud rather than a passing no-op run.
  if ! get_machine_groups "$MACHINE_HOSTNAME" >/dev/null 2>&1; then
    print_error "Unknown hostname '$MACHINE_HOSTNAME': no [$MACHINE_HOSTNAME] section in profiles.toml"
    print_info "Known hosts: $(get_known_hosts --csv)"
    print_info "Add a section to .system/profiles/profiles.toml, or pass --hostname <name>."
    print_info "Refusing to continue: every group-gated secret would be skipped."
    exit 1
  fi

  # Read work account domain from personal vault (work group machines only)
  OP_WORK_ACCOUNT=""
  if is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
    OP_WORK_ACCOUNT=$(read_work_account) || {
      print_error "Failed to read work 1Password account domain"
      print_info "Ensure '1password-work-account' item exists in Private vault"
      exit 1
    }
  fi

  # Ensure directories exist. 0700 so other local users cannot enumerate which
  # credentials exist; the files themselves are already 0600.
  mkdir -p "$SENSITIVE_DIR"
  chmod 700 "$SENSITIVE_DIR"
  mkdir -p "$TEMPLATES_DIR"

  # Work-only secrets (work group machines)
  if is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
    # Inject CI identity for empty commits
    if [[ -f "$TEMPLATES_DIR/ci-identity.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/ci-identity.tpl" "$SENSITIVE_DIR/ci-identity" "CI identity" "$OP_PERSONAL_ACCOUNT"
    fi

    # Inject clone.fish with work org
    if [[ -f "$TEMPLATES_DIR/clone.fish.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/clone.fish.tpl" "$DOTFILES/fish/functions/clone.fish" "Clone function" "$OP_PERSONAL_ACCOUNT"
    fi

    inject_spacelift "$OP_WORK_ACCOUNT"

    # AWS SSO profile config (hand-maintained, bidirectional)
    inject_aws_config || true

    # Context7 MCP API key, read by .system/mcp/context7-header.sh
    if [[ -f "$TEMPLATES_DIR/context7-api-key.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/context7-api-key.tpl" \
        "$SENSITIVE_DIR/context7-api-key" "Context7 API key" "$OP_PERSONAL_ACCOUNT" || true
    fi

    # Retrieve work-specific Claude skills from 1Password
    inject_claude_skills

    # Retrieve work-specific Claude rules from 1Password
    inject_claude_rules

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
    print_info "$MACHINE_HOSTNAME: skipping work-only secrets"
  fi

  # Server-only secrets
  if is_machine_in_group "$MACHINE_HOSTNAME" "server"; then
    if [[ -f "$TEMPLATES_DIR/rustdesk-password.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/rustdesk-password.tpl" "$SENSITIVE_DIR/rustdesk-password" "RustDesk password" "$OP_PERSONAL_ACCOUNT"
    fi

    if [[ -f "$TEMPLATES_DIR/anthropic-api-key.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/anthropic-api-key.tpl" "$SENSITIVE_DIR/anthropic-api-key" "Anthropic API key" "$OP_PERSONAL_ACCOUNT"

      cat >"$SENSITIVE_DIR/claude-api-key-helper.sh" <<'HELPER'
#!/bin/bash
cat ~/.config/.system/sensitive/anthropic-api-key
HELPER
      chmod 700 "$SENSITIVE_DIR/claude-api-key-helper.sh"
      print_status "Claude API key helper script created"
    fi

    if [[ -f "$TEMPLATES_DIR/tailscale-tailnet.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/tailscale-tailnet.tpl" "$SENSITIVE_DIR/tailscale-tailnet" "Tailscale tailnet name" "$OP_PERSONAL_ACCOUNT"
    fi

    if [[ -f "$TEMPLATES_DIR/tailscale-authkey.tpl" ]]; then
      inject_template "$TEMPLATES_DIR/tailscale-authkey.tpl" "$SENSITIVE_DIR/tailscale-authkey" "Tailscale OAuth client secret" "$OP_PERSONAL_ACCOUNT"
      chmod 600 "$SENSITIVE_DIR/tailscale-authkey"
    fi
  fi

  if [[ -f "$TEMPLATES_DIR/github-pat.tpl" ]]; then
    inject_template "$TEMPLATES_DIR/github-pat.tpl" "$SENSITIVE_DIR/github-pat" "GitHub PAT" "$OP_PERSONAL_ACCOUNT"
  fi

  # Refresh global Claude instructions from 1Password
  inject_claude_global

  # Inject npm token from 1Password
  if [[ -f "$TEMPLATES_DIR/npmrc.tpl" ]]; then
    inject_template "$TEMPLATES_DIR/npmrc.tpl" "$SENSITIVE_DIR/.npmrc" "npm token" "$OP_PERSONAL_ACCOUNT"
  fi

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
--check | -c)
  check_secrets
  ;;
--claude-global)
  check_op
  mkdir -p "$SENSITIVE_DIR"
  inject_claude_global
  ;;
--spacelift)
  check_op
  if ! is_machine_in_group "$MACHINE_HOSTNAME" "work"; then
    print_error "Spacelift credentials are work-only ($MACHINE_HOSTNAME is not in the 'work' group)"
    exit 1
  fi
  mkdir -p "$SENSITIVE_DIR"
  OP_WORK_ACCOUNT=$(read_work_account) || {
    print_error "Failed to read work 1Password account domain"
    exit 1
  }
  inject_spacelift "$OP_WORK_ACCOUNT"
  ;;
--help | -h)
  echo "Usage: $0 [--check|--claude-global|--spacelift|--help]"
  echo ""
  echo "Options:"
  echo "  --check, -c       Check which secrets are configured"
  echo "  --claude-global   Refresh CLAUDE.global.md only (from 1Password)"
  echo "  --spacelift       Refresh Spacelift credentials only (from 1Password)"
  echo "  --help, -h        Show this help message"
  echo ""
  echo "Without arguments, injects all secrets from 1Password."
  ;;
*)
  inject_secrets
  ;;
esac
