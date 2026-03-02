#!/usr/bin/env bash

# Reload Display Configuration
# Applies display profiles and reloads aerospace/sketchybar when display count changes

DISPLAY_COUNT="${1:-1}"
LOG_FILE="$HOME/.config/logs/display-reload.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set PATH to include Homebrew binaries
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Display count changed to: $DISPLAY_COUNT"

# Export display count for scripts to use
export DISPLAY_COUNT

# Apply display profile using displayplacer
if [[ -f "$SCRIPT_DIR/display-profiles.sh" ]]; then
    source "$SCRIPT_DIR/display-profiles.sh"
    log_message "Applying display profile..."
    apply_display_profile "$DISPLAY_COUNT" 2>&1 | while IFS= read -r line; do
        log_message "  displayplacer: $line"
    done
    # Small delay for macOS to settle after display changes
    sleep 0.5
fi

# Reload aerospace configuration
log_message "Reloading aerospace..."
aerospace reload-config 2>&1 | while IFS= read -r line; do
    log_message "  aerospace: $line"
done

# Small delay to ensure aerospace finishes
sleep 0.5

# Reload sketchybar
log_message "Reloading sketchybar..."
sketchybar --reload 2>&1 | while IFS= read -r line; do
    log_message "  sketchybar: $line"
done

log_message "Reload complete"
