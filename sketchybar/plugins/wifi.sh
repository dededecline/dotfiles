#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Check for ethernet connection on common interfaces (excluding en0 which is WiFi)
ETHERNET_IP=""
for iface in en1 en2 en3 en4 en5 en6 en7 en8 en9 en10 en11; do
  ip=$(ipconfig getifaddr "$iface" 2>/dev/null)
  if [ -n "$ip" ]; then
    ETHERNET_IP="$ip"
    break
  fi
done

if [ -n "$ETHERNET_IP" ]; then
  # Connected via Ethernet
  sketchybar --set "$NAME" icon=󰈀 icon.color=$YELLOW label=""
  exit 0
fi

# Get WiFi SSID
SSID=$(ipconfig getsummary en0 2>/dev/null | awk -F ' : ' '/SSID/ && !/BSSID/ {print $2}')

# Get WiFi IP address to detect iPhone hotspot (uses 172.20.10.x subnet)
WIFI_IP=$(ipconfig getifaddr en0 2>/dev/null)

if [ "$SSID" = "" ]; then
  # Not connected
  sketchybar --set "$NAME" icon=󰖪 icon.color=$RED label=""
elif [[ "$WIFI_IP" == 172.20.10.* ]]; then
  # Connected to iPhone Personal Hotspot (detected by IP range)
  sketchybar --set "$NAME" icon=󰌷 icon.color=$RED label=""
else
  # Normal WiFi connection
  sketchybar --set "$NAME" icon=󰖩 icon.color=$SKY label=""
fi
