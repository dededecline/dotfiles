#!/usr/bin/env bash

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"
SENSITIVE_DIR="$SYSTEM_DIR/sensitive"
TEMPLATES_DIR="$SYSTEM_DIR/templates"

TAG="tag:homeserver"
LABEL="com.user.tailnet-switch"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
LOG_FILE="$DOTFILES/logs/tailnet-switch.log"

source "$SYSTEM_DIR/setup/lib/output.sh"
source "$SYSTEM_DIR/setup/lib/profiles.sh"
source "$SYSTEM_DIR/setup/lib/tailnet.sh"

MACHINE_HOSTNAME="${MACHINE_HOSTNAME:-$(hostname -s)}"

print_policy() {
  cat <<POLICY
The target tailnet's policy must provide all three:

  1. tagOwners contains "$TAG"
  2. an ssh rule whose dst includes "$TAG", listing the users allowed to
     connect and the local accounts they may use
  3. grants permitting the traffic you need to reach this machine
     (a {"src": ["*"], "dst": ["*"], "ip": ["*"]} rule covers this)

Quickest way to confirm: if another machine already carries $TAG and you can
reach and SSH to it, this machine will be covered by the same rules.
POLICY
}

if [[ "${1:-}" == "--policy" ]]; then
  print_policy
  exit 0
fi

print_header "Tailnet Switch"

if ! is_machine_in_group "$MACHINE_HOSTNAME" "server"; then
  print_error "$MACHINE_HOSTNAME is not in the 'server' group. Refusing to run."
  exit 1
fi

if ! command -v tailscale &>/dev/null; then
  print_error "Tailscale is not installed"
  exit 1
fi

if ! tailscale status &>/dev/null; then
  print_error "tailscaled is not running. Start it before switching tailnets."
  exit 1
fi

for tool in jq envsubst; do
  if ! command -v "$tool" &>/dev/null; then
    print_error "$tool is required but not installed"
    exit 1
  fi
done

if ! EXPECTED=$(tailnet_expected_name "$SENSITIVE_DIR/tailscale-tailnet") || [[ -z "$EXPECTED" ]]; then
  print_error "Target tailnet unknown: $SENSITIVE_DIR/tailscale-tailnet is missing or empty"
  print_info "Run 'secrets' to inject it from 1Password."
  exit 1
fi

if [[ ! -s "$SENSITIVE_DIR/tailscale-authkey" ]]; then
  print_error "Missing credential: $SENSITIVE_DIR/tailscale-authkey"
  print_info "Run 'secrets' to inject it from 1Password."
  exit 1
fi

CURRENT=$(tailscale status --json | jq -r '.CurrentTailnet.Name // empty')
if tailnet_name_matches "$EXPECTED" "$CURRENT"; then
  print_status "Already on $CURRENT. Nothing to do."
  exit 0
fi

OLD_PROFILE=$(tailscale switch --list | tailnet_active_profile_id) || {
  print_error "Could not determine the active profile from 'tailscale switch --list'"
  exit 1
}
OLD_IP=$(tailscale ip -4 2>/dev/null || echo unknown)

print_info "Machine:        $MACHINE_HOSTNAME"
print_info "Current tailnet: ${CURRENT:-unknown} (profile $OLD_PROFILE, $OLD_IP)"
print_info "Target tailnet:  $EXPECTED (as $TAG)"
echo ""

# ListenAddress is ignored under launchd inetd mode, so record what is really
# listening rather than trusting sshd_config. See CLAUDE.md > Remote Access.
print_info "Listening on port 22 right now:"
sudo lsof -nP -iTCP:22 -sTCP:LISTEN 2>/dev/null || print_warning "  (could not read; lsof needs sudo)"
echo ""

print_warning "The target tailnet's policy must ALREADY grant this node access."
print_warning "If it does not, the switch will roll itself back."
echo ""
print_policy
echo ""

read -r -p "Does $EXPECTED already satisfy this? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  print_info "Aborted. Fix the policy, then run this again."
  exit 0
fi

print_info "Your Tailscale IP will change and this session will drop."
read -r -p "Proceed with the switch? [y/N] " reply
if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  print_info "Aborted. Nothing has changed."
  exit 0
fi

mkdir -p "$DOTFILES/logs"

sudo launchctl bootout "system/$LABEL" 2>/dev/null || true
sudo rm -f "$PLIST"

envsubst '$HOME' <"$TEMPLATES_DIR/tailnet-switch.plist.tpl" | sudo tee "$PLIST" >/dev/null
sudo chown root:wheel "$PLIST"
sudo chmod 644 "$PLIST"

print_status "Installed $PLIST"
sudo launchctl bootstrap system "$PLIST"
print_status "Switch handed to launchd. This session will drop shortly."

print_header "Reconnecting"
print_info "1. Wait ~1 minute, then find the new address from another device:"
print_info "     tailscale status | grep $MACHINE_HOSTNAME"
print_info "2. Reconnect:  ssh root@$MACHINE_HOSTNAME"
print_info "3. Review:     cat $LOG_FILE"
echo ""
print_info "If the switch failed it rolled back automatically: reconnect on"
print_info "${CURRENT:-the previous tailnet} at $OLD_IP and read the log."
