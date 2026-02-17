#!/usr/bin/env bash

# Disable Spotlight Shortcuts
# Runs at login via LaunchAgent to ensure Spotlight shortcuts stay disabled
# (macOS re-enables them on every restart)

LOG_FILE="$HOME/.config/logs/spotlight-shortcuts.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_message "Waiting for macOS to finish boot-time shortcut restoration..."
sleep 10

log_message "Disabling Spotlight keyboard shortcuts (keys 64, 65, 160)..."

PLIST="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
PB=/usr/libexec/PlistBuddy

disable_shortcut() {
    local key="$1" p1="$2" p2="$3" p3="$4"
    local base=":AppleSymbolicHotKeys:${key}"

    # Remove existing entry to avoid type conflicts
    "$PB" -c "Delete ${base}" "$PLIST" 2>/dev/null

    # Recreate with correct types
    "$PB" -c "Add ${base} dict" "$PLIST"
    "$PB" -c "Add ${base}:enabled bool false" "$PLIST"
    "$PB" -c "Add ${base}:value dict" "$PLIST"
    "$PB" -c "Add ${base}:value:type string standard" "$PLIST"
    "$PB" -c "Add ${base}:value:parameters array" "$PLIST"
    "$PB" -c "Add ${base}:value:parameters: integer ${p1}" "$PLIST"
    "$PB" -c "Add ${base}:value:parameters: integer ${p2}" "$PLIST"
    "$PB" -c "Add ${base}:value:parameters: integer ${p3}" "$PLIST"
}

# Spotlight Search: Cmd+Space (key 64)
disable_shortcut 64 65535 49 1048576

# Spotlight Finder Search: Cmd+Opt+Space (key 65)
disable_shortcut 65 65535 49 1572864

# Show Apps (Spotlight): key 160
disable_shortcut 160 65535 65535 0

# Flush preferences cache and apply changes without requiring logout
killall cfprefsd 2>/dev/null
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

log_message "Spotlight shortcuts disabled successfully"
