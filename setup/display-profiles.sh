#!/usr/bin/env bash
#
# display-profiles.sh - Display configuration profiles using displayplacer
#
# Manages display resolution, refresh rate, and arrangement based on
# connected monitors. Called by reload-display-config.sh when display
# count changes.
#

# Serial IDs for reliable monitor identification
# Both hera and athena MacBooks have the same display serial
MACBOOK_SERIAL="s4251086178"
EXTERNAL_SERIAL_1="s21573"
EXTERNAL_SERIAL_2="s825644620"

# Check if displayplacer is available
check_displayplacer() {
    if ! command -v displayplacer &>/dev/null; then
        echo "displayplacer not found - skipping display configuration"
        return 1
    fi
    return 0
}

# Single display: MacBook only at native resolution
apply_single_display() {
    displayplacer "id:$MACBOOK_SERIAL res:2560x1600 hz:120 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0"
}

# Dual display: MacBook + portable monitor
apply_dual_display_1() {
    displayplacer "id:$MACBOOK_SERIAL res:2560x1600 hz:120 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
                  "id:$EXTERNAL_SERIAL_1 res:2560x1600 hz:120 color_depth:8 enabled:true scaling:on origin:(0,-1600) degree:0"
}

# Dual display: MacBook + work office monitor
apply_dual_display_2() {
    displayplacer "id:$MACBOOK_SERIAL res:2560x1600 hz:120 color_depth:8 enabled:true scaling:on origin:(0,0) degree:0" \
                  "id:$EXTERNAL_SERIAL_2 res:2560x1440 hz:100 color_depth:8 enabled:true scaling:on origin:(0,-1440) degree:0"
}

# Apply appropriate display profile based on display count
apply_display_profile() {
    local display_count="${1:-1}"

    check_displayplacer || return 1

    if [[ "$display_count" -eq 1 ]]; then
        echo "Applying single display profile..."
        apply_single_display
    elif [[ "$display_count" -ge 2 ]]; then
        if displayplacer list 2>/dev/null | grep -q "$EXTERNAL_SERIAL_1"; then
            echo "Applying dual display profile (external monitor 1)..."
            apply_dual_display_1
        elif displayplacer list 2>/dev/null | grep -q "$EXTERNAL_SERIAL_2"; then
            echo "Applying dual display profile (external monitor 2)..."
            apply_dual_display_2
        else
            echo "Unknown external monitor - skipping display configuration"
        fi
    fi
}

# If run directly, apply profile based on current display count
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    display_count=$(system_profiler SPDisplaysDataType 2>/dev/null | grep -c "Resolution:")
    apply_display_profile "$display_count"
fi
