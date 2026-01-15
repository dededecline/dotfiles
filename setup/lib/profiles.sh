#!/usr/bin/env bash
#
# profiles.sh - Multi-machine profile detection and configuration
#
# Supports:
#   hera   -> work profile
#   athena -> personal profile
#

# =============================================================================
# Profile Mapping
# =============================================================================

# Hostname to profile mapping
declare -A HOSTNAME_TO_PROFILE=(
    ["hera"]="work"
    ["athena"]="personal"
)

# =============================================================================
# Profile Detection
# =============================================================================

# Detect profile from hostname or use override
# Usage: detect_profile [hostname_override]
# Returns: profile name (work/personal) or exits with error
detect_profile() {
    local hostname_override="$1"
    local hostname="${hostname_override:-$(hostname -s)}"
    local profile="${HOSTNAME_TO_PROFILE[$hostname]:-}"

    if [[ -z "$profile" ]]; then
        return 1
    fi

    echo "$profile"
}

# Get list of known hostnames for error messages
get_known_hosts() {
    local hosts=""
    for host in "${!HOSTNAME_TO_PROFILE[@]}"; do
        hosts+="$host (${HOSTNAME_TO_PROFILE[$host]}), "
    done
    # Remove trailing comma and space
    echo "${hosts%, }"
}

# Check if profile is work
is_work_profile() {
    [[ "${DOTFILES_PROFILE:-}" == "work" ]]
}

# Check if profile is personal
is_personal_profile() {
    [[ "${DOTFILES_PROFILE:-}" == "personal" ]]
}
