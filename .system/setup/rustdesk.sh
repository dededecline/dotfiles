#!/usr/bin/env bash
# Configure RustDesk for direct IP access over Tailscale

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"

# Source output utilities
source "$SYSTEM_DIR/setup/lib/output.sh"

RUSTDESK="/Applications/RustDesk.app/Contents/MacOS/RustDesk"

if [[ ! -f "$RUSTDESK" ]]; then
    print_warning "RustDesk not installed, skipping configuration"
    return 0 2>/dev/null || exit 0
fi

# Enable direct IP access (no relay server needed over Tailscale)
# sudo is required — RustDesk service runs as root on macOS and reads config from root's preferences
sudo "$RUSTDESK" --option direct-server=Y
# Clear any residual relay server config
sudo "$RUSTDESK" --option custom-rendezvous-server=
# Use permanent password (no click-to-approve)
sudo "$RUSTDESK" --option verification-method=use-permanent-password
sudo "$RUSTDESK" --option approve-mode=password

# Apply permanent password from 1Password if available
if [[ -f "$SYSTEM_DIR/sensitive/rustdesk-password" ]]; then
    # RustDesk CLI does not support stdin or file-based password input.
    sudo "$RUSTDESK" --password "$(tr -d '\n' < "$SYSTEM_DIR/sensitive/rustdesk-password")"
    print_status "RustDesk: configured with permanent password"
else
    print_warning "RustDesk: configured (set permanent password manually or via 'secrets')"
fi
