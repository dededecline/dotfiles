#!/usr/bin/env bash

# Display Monitor Watcher
# Detects changes in connected display count and triggers aerospace/sketchybar reload

CACHE_FILE="/tmp/display_count_cache"
RELOAD_SCRIPT="$HOME/.config/setup/reload-display-config.sh"

# Get current display count using system_profiler
get_display_count() {
    system_profiler SPDisplaysDataType | grep -c "Resolution:" | tr -d ' '
}

# Initialize cache file if it doesn't exist
if [ ! -f "$CACHE_FILE" ]; then
    get_display_count > "$CACHE_FILE"
    exit 0
fi

# Get cached and current display counts
CACHED_COUNT=$(cat "$CACHE_FILE")
CURRENT_COUNT=$(get_display_count)

# Check if display count has changed
if [ "$CACHED_COUNT" != "$CURRENT_COUNT" ]; then
    echo "$(date): Display count changed from $CACHED_COUNT to $CURRENT_COUNT"

    # Update cache
    echo "$CURRENT_COUNT" > "$CACHE_FILE"

    # Trigger reload
    if [ -x "$RELOAD_SCRIPT" ]; then
        "$RELOAD_SCRIPT" "$CURRENT_COUNT"
    else
        echo "Warning: Reload script not found or not executable: $RELOAD_SCRIPT"
    fi
fi
