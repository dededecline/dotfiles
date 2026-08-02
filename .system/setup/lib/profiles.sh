#!/usr/bin/env bash
#
# Multi-machine hostname detection and configuration
# Single source of truth: .system/profiles/profiles.toml
# Defines all known machines and their group memberships.

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"
PROFILES_TOML="${PROFILES_TOML:-$SYSTEM_DIR/profiles/profiles.toml}"

is_known_hostname() {
  [[ -n "$1" ]] && grep -qxF "[$1]" "$PROFILES_TOML"
}

get_known_hosts() {
  local hosts=()
  local line
  while IFS= read -r line; do
    hosts+=("$line")
  done < <(grep -E '^\[[a-zA-Z0-9_-]+\]$' "$PROFILES_TOML" | sed 's/[][]//g')
  if [[ "${1-}" == "--csv" ]]; then
    local result
    printf -v result '%s, ' "${hosts[@]}"
    echo "${result%, }"
  else
    printf '%s\n' "${hosts[@]}"
  fi
}

get_machine_groups() {
  local hostname="$1"
  local groups=()
  local in_host=false

  if ! is_known_hostname "$hostname"; then
    echo "ERROR: unknown hostname '${hostname}': no [${hostname}] section in ${PROFILES_TOML}" >&2
    echo "       Add it to profiles.toml, or pass ./setup.sh --hostname <name>." >&2
    return 1
  fi

  while IFS= read -r line; do
    # Section header
    if [[ "$line" =~ ^\[[a-zA-Z0-9_-]+\]$ ]]; then
      if [[ "$line" == "[${hostname}]" ]]; then
        in_host=true
      else
        $in_host && break
      fi
      continue
    fi
    # Groups line under the current host
    if $in_host && [[ "$line" =~ ^groups[[:space:]]*=[[:space:]]*\[(.+)\]$ ]]; then
      local raw="${BASH_REMATCH[1]}"
      # Strip quotes and split on comma
      raw="${raw//\"/}"
      IFS=',' read -ra items <<<"$raw"
      for item in "${items[@]}"; do
        # Trim whitespace
        item="${item#"${item%%[![:space:]]*}"}"
        item="${item%"${item##*[![:space:]]}"}"
        [[ -n "$item" ]] && groups+=("$item")
      done
    fi
  done <"$PROFILES_TOML"

  if [[ ${#groups[@]} -eq 0 ]]; then
    echo "all $hostname"
  else
    echo "${groups[*]} $hostname"
  fi
}

# Check if a hostname belongs to a specific group
# Usage: is_machine_in_group <hostname> <group>
is_machine_in_group() {
  local hostname="$1" group="$2"
  local groups
  groups=$(get_machine_groups "$hostname") || return 1
  [[ " $groups " == *" $group "* ]]
}
