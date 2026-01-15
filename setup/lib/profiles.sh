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

# Get profile for a hostname
# Usage: get_profile_for_hostname <hostname>
get_profile_for_hostname() {
    case "$1" in
        hera)   echo "work" ;;
        athena) echo "personal" ;;
        *)      echo "" ;;
    esac
}

# =============================================================================
# Profile Detection
# =============================================================================

# Detect profile from hostname or use override
# Usage: detect_profile [hostname_override]
# Returns: profile name (work/personal) or empty string if unknown
detect_profile() {
    local hostname_override="${1:-}"
    local hostname="${hostname_override:-$(hostname -s)}"
    get_profile_for_hostname "$hostname"
}

# Get list of known hostnames for error messages
get_known_hosts() {
    echo "hera (work), athena (personal)"
}

# Check if profile is work
is_work_profile() {
    [[ "${DOTFILES_PROFILE:-}" == "work" ]]
}

# Check if profile is personal
is_personal_profile() {
    [[ "${DOTFILES_PROFILE:-}" == "personal" ]]
}
