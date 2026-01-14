#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Get WiFi info
WIFI=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I)
SSID=$(echo "$WIFI" | grep -o "SSID: .*" | sed 's/^SSID: //')

if [ "$SSID" = "" ]; then
  sketchybar --set "$NAME" icon=󰖪 icon.color=$RED label=""
else
  sketchybar --set "$NAME" icon=󰖩 icon.color=$SKY label=""
fi
