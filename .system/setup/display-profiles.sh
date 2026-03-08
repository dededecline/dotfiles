#!/usr/bin/env bash
#
# Display configuration profiles using displayplacer
# Manages display resolution, refresh rate, and arrangement based on
# connected monitors. Called by reload-display-config.sh when display
# count changes.
#
# Monitor definitions live in .system/profiles/displays.toml.

MONITOR_NAMES=()
DP_LIST=""

# Parse displays.toml into MONITOR_<name>_<key> variables
parse_displays_toml() {
    local config="${SYSTEM_DIR:-$HOME/.config/.system}/profiles/displays.toml"
    [[ -f "$config" ]] || { echo "displays.toml not found: $config"; return 1; }
    MONITOR_NAMES=()
    local section=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        if [[ "$line" =~ ^\[([a-zA-Z0-9_-]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            MONITOR_NAMES+=("$section")
            continue
        fi
        if [[ -n "$section" && "$line" =~ ^([a-zA-Z_]+)[[:space:]]*=[[:space:]]*\"(.*)\"$ ]]; then
            printf -v "MONITOR_${section}_${BASH_REMATCH[1]}" '%s' "${BASH_REMATCH[2]}"
        fi
    done < "$config"
}

# Cache displayplacer list output (single subprocess instead of many)
get_dp_list() {
    [[ -z "$DP_LIST" ]] && DP_LIST=$(displayplacer list 2>/dev/null)
    echo "$DP_LIST"
}

# Check if machine has a built-in display (MacBook vs desktop)
has_builtin_display() {
    get_dp_list | grep -q "Type: MacBook built in screen"
}

# Dynamically find the MacBook built-in display's persistent screen id
get_macbook_id() {
    local last_id=""
    while IFS= read -r line; do
        if [[ "$line" =~ Persistent\ screen\ id:\ +(.*) ]]; then
            last_id="${BASH_REMATCH[1]}"
        elif [[ "$line" == *"Type: MacBook built in screen"* ]]; then
            echo "$last_id"
            return 0
        fi
    done < <(get_dp_list)
    return 1
}

# Check if displayplacer is available
check_displayplacer() {
    if ! command -v displayplacer &>/dev/null; then
        echo "displayplacer not found, skipping display configuration"
        return 1
    fi
    return 0
}

# Build one displayplacer argument string from config
# Usage: build_dp_arg <monitor_name> <origin>
build_dp_arg() {
    local name="$1" origin="$2" id serial _key
    _key="MONITOR_${name}_serial"; serial="${!_key}"
    if [[ -z "$serial" ]]; then
        id=$(get_macbook_id) || return 1
    else
        id="$serial"
    fi
    local res hz color_depth
    _key="MONITOR_${name}_res"; res="${!_key}"
    _key="MONITOR_${name}_hz"; hz="${!_key}"
    _key="MONITOR_${name}_color_depth"; color_depth="${!_key}"
    echo "id:$id res:$res hz:$hz color_depth:$color_depth enabled:true scaling:on origin:$origin degree:0"
}

# Find which non-builtin monitors are currently connected
find_connected_externals() {
    local dp_list name serial _key
    dp_list=$(get_dp_list)
    for name in "${MONITOR_NAMES[@]}"; do
        _key="MONITOR_${name}_serial"; serial="${!_key}"
        [[ -z "$serial" ]] && continue
        echo "$dp_list" | grep -qF "$serial" && echo "$name"
    done
}

# Apply appropriate display profile based on display count
apply_display_profile() {
    check_displayplacer || return 1
    parse_displays_toml || return 1

    # Pre-populate cache so subshell calls to get_dp_list reuse it
    DP_LIST=$(displayplacer list 2>/dev/null)

    local has_builtin=false
    has_builtin_display && has_builtin=true

    # Collect connected external monitors
    local externals=()
    while IFS= read -r name; do
        [[ -n "$name" ]] && externals+=("$name")
    done < <(find_connected_externals)

    local args=()

    if $has_builtin; then
        local builtin_arg
        builtin_arg=$(build_dp_arg builtin "(0,0)") || {
            echo "Could not detect MacBook built-in display, skipping display configuration"
            return 1
        }
        args+=("$builtin_arg")
    fi

    if [[ ${#externals[@]} -eq 0 ]]; then
        if ! $has_builtin; then
            echo "No displays connected, skipping display configuration"
            return 0
        fi
        # builtin-only: args already has the builtin entry
    elif [[ ${#externals[@]} -eq 1 ]]; then
        local ext="${externals[0]}"
        if $has_builtin; then
            local dual_origin _key
            _key="MONITOR_${ext}_dual_origin"; dual_origin="${!_key}"
            args+=("$(build_dp_arg "$ext" "$dual_origin")")
        else
            args+=("$(build_dp_arg "$ext" "(0,0)")")
        fi
    else
        # 2+ externals
        if $has_builtin; then
            for ext in "${externals[@]}"; do
                local dual_origin _key
                _key="MONITOR_${ext}_dual_origin"; dual_origin="${!_key}"
                args+=("$(build_dp_arg "$ext" "$dual_origin")")
            done
        else
            local first=true
            for ext in "${externals[@]}"; do
                if $first; then
                    args+=("$(build_dp_arg "$ext" "(0,0)")")
                    first=false
                else
                    local dual_origin _key
                    _key="MONITOR_${ext}_dual_origin"; dual_origin="${!_key}"
                    args+=("$(build_dp_arg "$ext" "$dual_origin")")
                fi
            done
        fi
    fi

    if [[ ${#args[@]} -gt 0 ]]; then
        echo "Applying display profile (${#args[@]} display(s))..."
        displayplacer "${args[@]}"
    fi
}

# If run directly, apply profile based on current display count
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    apply_display_profile
fi
