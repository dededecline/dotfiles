#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Get memory stats using vm_stat (efficient macOS command)
VM_STAT=$(vm_stat)

# Parse values (pages, each page is 4096 bytes on macOS)
PAGES_FREE=$(echo "$VM_STAT" | awk '/Pages free/ {gsub(/\./, "", $3); print $3}')
PAGES_ACTIVE=$(echo "$VM_STAT" | awk '/Pages active/ {gsub(/\./, "", $3); print $3}')
PAGES_INACTIVE=$(echo "$VM_STAT" | awk '/Pages inactive/ {gsub(/\./, "", $3); print $3}')
PAGES_SPECULATIVE=$(echo "$VM_STAT" | awk '/Pages speculative/ {gsub(/\./, "", $3); print $3}')
PAGES_WIRED=$(echo "$VM_STAT" | awk '/Pages wired down/ {gsub(/\./, "", $4); print $4}')
PAGES_COMPRESSED=$(echo "$VM_STAT" | awk '/Pages occupied by compressor/ {gsub(/\./, "", $5); print $5}')

# Default to 0 if empty
PAGES_FREE=${PAGES_FREE:-0}
PAGES_ACTIVE=${PAGES_ACTIVE:-0}
PAGES_INACTIVE=${PAGES_INACTIVE:-0}
PAGES_SPECULATIVE=${PAGES_SPECULATIVE:-0}
PAGES_WIRED=${PAGES_WIRED:-0}
PAGES_COMPRESSED=${PAGES_COMPRESSED:-0}

# Calculate used and total memory
USED=$((PAGES_ACTIVE + PAGES_WIRED + PAGES_COMPRESSED))
TOTAL=$((PAGES_FREE + PAGES_ACTIVE + PAGES_INACTIVE + PAGES_SPECULATIVE + PAGES_WIRED + PAGES_COMPRESSED))

# Calculate percentage
if [ "$TOTAL" -gt 0 ]; then
  MEM_PERCENT=$((USED * 100 / TOTAL))
else
  MEM_PERCENT=0
fi

# Color based on usage
if [ "$MEM_PERCENT" -gt 80 ]; then
  COLOR=$RED
elif [ "$MEM_PERCENT" -gt 50 ]; then
  COLOR=$MAUVE
else
  COLOR=$GREEN
fi

sketchybar --set "$NAME" label="${MEM_PERCENT}%" icon.color="$COLOR"
