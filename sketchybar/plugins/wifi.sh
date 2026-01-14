#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Get WiFi SSID (airport command is deprecated on modern macOS)
SSID=$(ipconfig getsummary en0 2>/dev/null | awk -F ' : ' '/SSID/ && !/BSSID/ {print $2}')

if [ "$SSID" = "" ]; then
  sketchybar --set "$NAME" icon=󰖪 icon.color=$RED label=""
else
  sketchybar --set "$NAME" icon=󰖩 icon.color=$SKY label=""
fi
