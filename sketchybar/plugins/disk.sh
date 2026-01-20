#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Get disk usage for root volume (Macintosh HD)
DISK_PERCENT=$(df -h / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')

# Default to 0 if empty
DISK_PERCENT=${DISK_PERCENT:-0}

# Color based on usage
if [ "$DISK_PERCENT" -gt 90 ]; then
  COLOR=$RED
elif [ "$DISK_PERCENT" -gt 75 ]; then
  COLOR=$YELLOW
else
  COLOR=$TEAL
fi

sketchybar --set "$NAME" label="${DISK_PERCENT}%" icon.color="$COLOR"
