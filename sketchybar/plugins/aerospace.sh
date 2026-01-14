#!/bin/bash

# Aerospace workspace change handler
# Highlights the focused workspace with Catppuccin Frappe lavender accent

source "$CONFIG_DIR/colors.sh"

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  # Focused workspace: lavender accent background with border
  sketchybar --set "$NAME" \
    background.color=$SPACE_ACTIVE_BG \
    background.border_color=$LAVENDER \
    background.border_width=2 \
    icon.color=$LAVENDER \
    label.color=$TEXT
else
  # Unfocused workspace: subtle background
  sketchybar --set "$NAME" \
    background.color=$ITEM_BG_COLOR \
    background.border_width=0 \
    icon.color=$TEXT \
    label.color=$SUBTEXT0
fi
