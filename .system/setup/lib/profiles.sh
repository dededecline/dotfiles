#!/usr/bin/env bash
#
# profiles.sh - Multi-machine hostname detection and configuration
#
# Reads machine definitions from the .system/profiles/ directory:
#   .system/profiles/individual/*/       - Known hostnames (directory names)
#   .system/profiles/shared/*/hostnames  - Group membership (one hostname per line)

DOTFILES="${DOTFILES:-$HOME/.config}"
SYSTEM_DIR="${SYSTEM_DIR:-$DOTFILES/.system}"

# Validate a hostname is known
is_known_hostname() {
    [[ -n "$1" ]] && [[ -d "$SYSTEM_DIR/profiles/individual/$1" ]]
}

# Get known hostnames
# Usage: get_known_hosts         → one per line
#        get_known_hosts --csv   → comma-separated (e.g. "hera, athena, nyx")
get_known_hosts() {
    local hosts=()
    local dir
    for dir in "$SYSTEM_DIR/profiles/individual"/*/; do
        [[ -d "$dir" ]] && hosts+=("$(basename "$dir")")
    done
    if [[ "${1-}" == "--csv" ]]; then
        local result
        printf -v result '%s, ' "${hosts[@]}"
        echo "${result%, }"
    else
        printf '%s\n' "${hosts[@]}"
    fi
}

# Get machine groups for a hostname
# Used for both Brewfile composition and JSONC marker filtering
# Returns space-separated list matching: shared dirs + the hostname itself
get_machine_groups() {
    local hostname="$1"
    local groups=()
    local hostnames_file
    for hostnames_file in "$SYSTEM_DIR/profiles/shared"/*/hostnames; do
        [[ -f "$hostnames_file" ]] || continue
        if grep -qx "$hostname" "$hostnames_file"; then
            groups+=("$(basename "$(dirname "$hostnames_file")")")
        fi
    done
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
    local hostnames_file="$SYSTEM_DIR/profiles/shared/$group/hostnames"
    [[ -f "$hostnames_file" ]] && grep -qx "$hostname" "$hostnames_file"
}
