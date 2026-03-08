#!/usr/bin/env bash
# Configure Tailscale SSH on server machines

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"

# Source output utilities
source "$SYSTEM_DIR/setup/lib/output.sh"

if ! command -v tailscale &>/dev/null; then
    print_warning "Tailscale not installed — skipping"
    return 0 2>/dev/null || exit 0
fi

# Check if tailscaled is running
if ! tailscale status &>/dev/null; then
    print_info "Starting tailscaled service..."
    sudo brew services start tailscale
    print_warning "Run 'tailscale up' to authenticate (SSH will be enabled on next setup run)"
    return 0 2>/dev/null || exit 0
fi

# Enable Tailscale SSH server (idempotent)
# Security: Access is governed by Tailscale ACLs (managed in Tailscale admin console).
# Ensure ACLs restrict SSH access to authorized users/devices only.
# Default tailnet policy (allow-all) would grant SSH to any tailnet member.
# Configure ACLs at: https://login.tailscale.com/admin/acls
tailscale set --ssh

print_status "Tailscale SSH: enabled (verify ACLs at https://login.tailscale.com/admin/acls)"

# Restrict SSH to Tailscale interface only (idempotent via marker comment)
# Comment out any pre-existing ListenAddress not managed by dotfiles
sudo sed -i '' '/^ListenAddress/{ /# managed by dotfiles$/!s/^/# /; }' /etc/ssh/sshd_config
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
if [[ -n "$TAILSCALE_IP" ]] && [[ "$TAILSCALE_IP" =~ ^100\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    sudo sed -i '' '/# managed by dotfiles$/d' /etc/ssh/sshd_config
    echo "ListenAddress $TAILSCALE_IP  # managed by dotfiles" | sudo tee -a /etc/ssh/sshd_config >/dev/null
    sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
    print_status "SSH restricted to Tailscale interface ($TAILSCALE_IP)"
else
    print_warning "Tailscale IP not found — restricting SSH to localhost"
    sudo sed -i '' '/# managed by dotfiles$/d' /etc/ssh/sshd_config
    echo "ListenAddress 127.0.0.1  # managed by dotfiles" | sudo tee -a /etc/ssh/sshd_config >/dev/null
    sudo launchctl kickstart -k system/com.openssh.sshd 2>/dev/null || true
fi
