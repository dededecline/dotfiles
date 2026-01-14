#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Get disk I/O using iostat
# -d = disk stats only, -c 2 = take 2 samples (first is since boot, second is current)
# We want the second sample for current activity
IOSTAT=$(iostat -d -c 2 2>/dev/null | tail -n 1)

# Parse KB/s transferred (column 3 is KB/t, but we want total throughput)
# iostat gives: KB/t, tps, MB/s for each disk
# Get MB/s (column 3)
MB_S=$(echo "$IOSTAT" | awk '{print $3}')

# Default to 0 if empty or invalid
if [ -z "$MB_S" ] || [ "$MB_S" = "0.00" ]; then
  MB_S="0"
fi

# Format output - convert to integer for display
MB_INT=$(printf "%.0f" "$MB_S" 2>/dev/null || echo "0")

# Adaptive display: show GB/s if over 1000 MB/s
if [ "$MB_INT" -ge 1000 ]; then
  GB_S=$(echo "scale=1; $MB_S / 1024" | bc 2>/dev/null || echo "0")
  LABEL="${GB_S} G"
else
  LABEL="${MB_INT} M"
fi

# Color based on activity (high I/O gets highlighted)
if [ "$MB_INT" -gt 100 ]; then
  COLOR=$TEAL
else
  COLOR=$TEAL
fi

sketchybar --set "$NAME" label="$LABEL" icon.color="$COLOR"
