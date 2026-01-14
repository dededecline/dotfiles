#!/bin/bash

source "$CONFIG_DIR/colors.sh"

CACHE_FILE="/tmp/sketchybar_disk_io"

# Get cumulative disk I/O bytes from ioreg (sums all disks)
get_disk_bytes() {
  ioreg -c IOBlockStorageDriver -r -w 0 2>/dev/null | \
    awk '/"Bytes \(Read\)"/ {read+=$NF} /"Bytes \(Write\)"/ {write+=$NF} END {print read, write}'
}

# Read current bytes
CURRENT=$(get_disk_bytes)
READ_BYTES=$(echo "$CURRENT" | awk '{print $1}')
WRITE_BYTES=$(echo "$CURRENT" | awk '{print $2}')
CURRENT_TIME=$(date +%s)

# Default values if ioreg failed
READ_BYTES=${READ_BYTES:-0}
WRITE_BYTES=${WRITE_BYTES:-0}

# Read previous values from cache
if [ -f "$CACHE_FILE" ]; then
  read -r PREV_READ PREV_WRITE PREV_TIME < "$CACHE_FILE"
else
  PREV_READ=$READ_BYTES
  PREV_WRITE=$WRITE_BYTES
  PREV_TIME=$CURRENT_TIME
fi

# Save current values to cache
echo "$READ_BYTES $WRITE_BYTES $CURRENT_TIME" > "$CACHE_FILE"

# Calculate time delta (minimum 1 second to avoid division by zero)
TIME_DELTA=$((CURRENT_TIME - PREV_TIME))
[ "$TIME_DELTA" -le 0 ] && TIME_DELTA=1

# Calculate byte deltas (handle counter reset/wrap)
READ_DELTA=$((READ_BYTES - PREV_READ))
WRITE_DELTA=$((WRITE_BYTES - PREV_WRITE))
[ "$READ_DELTA" -lt 0 ] && READ_DELTA=0
[ "$WRITE_DELTA" -lt 0 ] && WRITE_DELTA=0

# Convert to MB/s
READ_MBS=$(echo "scale=1; $READ_DELTA / $TIME_DELTA / 1048576" | bc 2>/dev/null || echo "0")
WRITE_MBS=$(echo "scale=1; $WRITE_DELTA / $TIME_DELTA / 1048576" | bc 2>/dev/null || echo "0")

# Format to integers for cleaner display
READ_INT=$(printf "%.0f" "$READ_MBS" 2>/dev/null || echo "0")
WRITE_INT=$(printf "%.0f" "$WRITE_MBS" 2>/dev/null || echo "0")

# Display format: ↓read ↑write (in MB/s)
LABEL="↓${READ_INT} ↑${WRITE_INT}"

sketchybar --set "$NAME" label="$LABEL" icon.color="$TEAL"
