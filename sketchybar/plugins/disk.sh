#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Get APFS container usage (total disk, not just root volume)
TOTAL=$(diskutil info disk3s5 | grep "Container Total Space" | sed 's/.*(\([0-9]*\) Bytes).*/\1/')
FREE=$(diskutil info disk3s5 | grep "Container Free Space" | sed 's/.*(\([0-9]*\) Bytes).*/\1/')
if [ -n "$TOTAL" ] && [ -n "$FREE" ] && [ "$TOTAL" -gt 0 ]; then
  USED=$((TOTAL - FREE))
  DISK_PERCENT=$((USED * 100 / TOTAL))
else
  # Fallback to df if diskutil fails
  DISK_PERCENT=$(df -h / | awk 'NR==2 {gsub(/%/, "", $5); print $5}')
fi

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
