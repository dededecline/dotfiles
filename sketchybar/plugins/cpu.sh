#!/bin/bash

source "$CONFIG_DIR/colors.sh"

CPU=$(top -l 1 | grep -E "^CPU" | grep -Eo '[0-9]+\.[0-9]+%' | head -1 | sed 's/%//')

# Round to integer
CPU_INT=${CPU%.*}

if [ -z "$CPU_INT" ]; then
  CPU_INT=0
fi

# Color based on usage
if [ "$CPU_INT" -gt 80 ]; then
  COLOR=$RED
elif [ "$CPU_INT" -gt 50 ]; then
  COLOR=$PEACH
else
  COLOR=$GREEN
fi

sketchybar --set "$NAME" label="${CPU_INT}%" icon.color="$COLOR"
