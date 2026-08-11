#!/usr/bin/env bash

set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"
SENSITIVE_DIR="$SYSTEM_DIR/sensitive"
export DOTFILES SYSTEM_DIR

TAG="tag:homeserver"
LABEL="com.user.tailnet-switch"
PLIST="/Library/LaunchDaemons/${LABEL}.plist"
STATE_FILE="$SENSITIVE_DIR/tailnet-switch-state"
LOG_DIR="$DOTFILES/logs"

LOGIN_TIMEOUT=90
HEALTHY_TIMEOUT=150

source "$SYSTEM_DIR/setup/lib/tailnet.sh"

OLD_PROFILE=""
ROLLBACK_AVAILABLE=true

log() {
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
}

run_with_timeout() {
  local secs="$1"
  shift
  "$@" 2>&1 &
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if ((waited >= secs)); then
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      kill -KILL "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 124
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

apply_tailscale_config() {
  bash "$SYSTEM_DIR/setup/tailscale.sh" 2>&1
}

uninstall_self() {
  rm -f "$PLIST"
  log "removed $PLIST (will not run again at boot)"
}

rollback() {
  log "ROLLING BACK: $1"

  if [[ "$ROLLBACK_AVAILABLE" != true ]] || [[ -z "$OLD_PROFILE" ]]; then
    log "FATAL: no usable rollback profile. This machine may be unreachable."
    log "Recover with physical or LAN access: tailscale switch --list"
    uninstall_self
    exit 1
  fi

  if tailscale switch "$OLD_PROFILE" 2>&1; then
    log "switched back to profile $OLD_PROFILE"
  else
    log "FATAL: 'tailscale switch $OLD_PROFILE' failed. Machine may be unreachable."
    uninstall_self
    exit 1
  fi

  apply_tailscale_config
  log "restored SSH config for the previous tailnet: $(tailscale ip -4 2>/dev/null || echo unknown)"
  log "Check the target tailnet's admin console for a stale node and remove it."
  uninstall_self
  exit 1
}

wait_for_healthy() {
  local expected="$1"
  local deadline=$((SECONDS + HEALTHY_TIMEOUT))
  local json state name ips

  while ((SECONDS < deadline)); do
    json=$(tailscale status --json 2>/dev/null)
    if [[ -n "$json" ]]; then
      state=$(jq -r '.BackendState // empty' <<<"$json")
      name=$(jq -r '.CurrentTailnet.Name // empty' <<<"$json")
      ips=$(jq -r '(.TailscaleIPs // []) | length' <<<"$json")

      if [[ "$state" == "Running" ]] && ((ips > 0)) && tailnet_name_matches "$expected" "$name"; then
        log "healthy: tailnet=$name state=$state addresses=$ips"
        return 0
      fi
      log "waiting: state=${state:-?} tailnet=${name:-?} addresses=${ips:-0}"
    else
      log "waiting: tailscale status unavailable"
    fi
    sleep 3
  done

  return 1
}

check_policy_grants_access() {
  local json peers online
  json=$(tailscale status --json 2>/dev/null) || return 1
  peers=$(jq -r '(.Peer // {}) | length' <<<"$json")
  online=$(jq -r '[(.Peer // {}) | .[] | select(.Online)] | length' <<<"$json")

  if ((peers == 0)); then
    log "no peers visible: the tailnet policy is not granting this node access"
    return 1
  fi

  log "policy check: $peers peer(s) visible, $online online"
  if ((online == 0)); then
    log "WARNING: no peers currently online. Cannot confirm reachability now."
  fi
  return 0
}

main() {
  mkdir -p "$LOG_DIR"
  log "=== tailnet switch starting (pid $$) ==="

  local expected authkey
  if ! expected=$(tailnet_expected_name "$SENSITIVE_DIR/tailscale-tailnet") || [[ -z "$expected" ]]; then
    log "ABORT: $SENSITIVE_DIR/tailscale-tailnet missing or empty. Run 'secrets'."
    uninstall_self
    exit 1
  fi

  local current
  current=$(tailscale status --json 2>/dev/null | jq -r '.CurrentTailnet.Name // empty')
  if tailnet_name_matches "$expected" "$current"; then
    log "already on the expected tailnet ($current). Nothing to do."
    apply_tailscale_config
    uninstall_self
    exit 0
  fi

  if [[ ! -s "$SENSITIVE_DIR/tailscale-authkey" ]]; then
    log "ABORT: $SENSITIVE_DIR/tailscale-authkey missing or empty. Run 'secrets'."
    uninstall_self
    exit 1
  fi
  authkey=$(tr -d '\n' <"$SENSITIVE_DIR/tailscale-authkey")

  OLD_PROFILE=$(tailscale switch --list 2>/dev/null | tailnet_active_profile_id)
  if [[ -z "$OLD_PROFILE" ]]; then
    log "ABORT: could not determine the current profile. Refusing to switch blind."
    uninstall_self
    exit 1
  fi
  local old_ip
  old_ip=$(tailscale ip -4 2>/dev/null || echo unknown)
  log "current profile=$OLD_PROFILE tailnet=${current:-unknown} ip=$old_ip"
  printf 'profile=%s\nip=%s\ntarget=%s\n' "$OLD_PROFILE" "$old_ip" "$expected" >"$STATE_FILE"

  log "authenticating to $expected as $TAG"
  run_with_timeout "$LOGIN_TIMEOUT" \
    tailscale login \
    --auth-key="${authkey}?ephemeral=false&preauthorized=true" \
    --advertise-tags="$TAG"
  local rc=$?
  if ((rc == 124)); then
    log "'tailscale login' timed out after ${LOGIN_TIMEOUT}s"
  elif ((rc != 0)); then
    log "'tailscale login' exited $rc"
  fi

  if ! tailscale switch --list 2>/dev/null | awk -v id="$OLD_PROFILE" '$1 == id { found = 1 } END { exit !found }'; then
    ROLLBACK_AVAILABLE=false
    log "WARNING: profile $OLD_PROFILE is no longer listed. ROLLBACK UNAVAILABLE."
  fi

  if ((rc != 0)); then
    rollback "authentication to $expected failed"
  fi

  if ! wait_for_healthy "$expected"; then
    rollback "did not reach Running on $expected within ${HEALTHY_TIMEOUT}s"
  fi

  if ! apply_tailscale_config; then
    rollback "failed to re-apply Tailscale SSH and sshd ListenAddress"
  fi

  if ! check_policy_grants_access; then
    rollback "tailnet policy does not grant this node access"
  fi

  log "SUCCESS: now on $expected as $TAG at $(tailscale ip -4 2>/dev/null || echo unknown)"
  log "previous profile $OLD_PROFILE retained. Remove it once you are confident."
  uninstall_self
  log "=== tailnet switch complete ==="
}

main "$@"
