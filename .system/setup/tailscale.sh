#!/usr/bin/env bash
# Configure Tailscale SSH on server machines

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"
SENSITIVE_DIR="${SENSITIVE_DIR:-$SYSTEM_DIR/sensitive}"

# Source output utilities
source "$SYSTEM_DIR/setup/lib/output.sh"
source "$SYSTEM_DIR/setup/lib/tailnet.sh"

if ! command -v tailscale &>/dev/null; then
  print_warning "Tailscale not installed, skipping"
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

# Check if tailscaled is running
if ! tailscale status &>/dev/null; then
  print_info "Starting tailscaled service..."
  sudo brew services start tailscale
  print_warning "Run 'tailscale up' to authenticate (SSH will be enabled on next setup run)"
  # shellcheck disable=SC2317
  return 0 2>/dev/null || exit 0
fi

EXPECTED_TAILNET="$(tailnet_expected_name "$SENSITIVE_DIR/tailscale-tailnet" || true)"
if [[ -z "$EXPECTED_TAILNET" ]]; then
  print_info "Tailnet: no expected tailnet configured (run 'secrets')"
elif ! command -v jq &>/dev/null; then
  print_warning "Tailnet: cannot verify without jq"
else
  CURRENT_TAILNET=$(tailscale status --json 2>/dev/null | jq -r '.CurrentTailnet.Name // empty')
  if tailnet_name_matches "$EXPECTED_TAILNET" "$CURRENT_TAILNET"; then
    print_status "Tailnet: $CURRENT_TAILNET"
  else
    print_warning "Tailnet drift: on '${CURRENT_TAILNET:-unknown}', expected '$EXPECTED_TAILNET'"
    print_info "Move with: bash $SYSTEM_DIR/setup/tailnet-switch.sh"
  fi
fi

tailscale set --ssh

print_status "Tailscale SSH: enabled (verify policy at https://login.tailscale.com/admin/acls)"

sudo sed -i '' '/^ListenAddress/{ /# managed by dotfiles$/!s/^/# /; }' /etc/ssh/sshd_config
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
if [[ -n "$TAILSCALE_IP" ]] && [[ "$TAILSCALE_IP" =~ ^100\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  sudo sed -i '' '/# managed by dotfiles$/d' /etc/ssh/sshd_config
  echo "ListenAddress $TAILSCALE_IP  # managed by dotfiles" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
  print_status "SSH restricted to Tailscale interface ($TAILSCALE_IP)"
else
  print_warning "Tailscale IP not found, restricting SSH to localhost"
  sudo sed -i '' '/# managed by dotfiles$/d' /etc/ssh/sshd_config
  echo "ListenAddress 127.0.0.1  # managed by dotfiles" | sudo tee -a /etc/ssh/sshd_config >/dev/null
  sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
fi

# Install kitty terminfo for SSH clients connecting from kitty terminal
TERMINFO_SRC="$SYSTEM_DIR/templates/xterm-kitty.terminfo"
if [[ ! -f "$TERMINFO_SRC" ]]; then
  print_warning "Kitty terminfo: source not found ($TERMINFO_SRC)"
elif [[ ! -f "$HOME/.terminfo/78/xterm-kitty" ]]; then
  tic -x -o "$HOME/.terminfo" "$TERMINFO_SRC"
  print_status "Kitty terminfo: installed"
else
  print_status "Kitty terminfo: already installed"
fi
