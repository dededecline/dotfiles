#!/bin/bash

# Front app change handler - updates icon and label for focused application

if [ "$SENDER" = "front_app_switched" ]; then
  # Get the app icon from the icon map
  icon=$($CONFIG_DIR/plugins/icon_map_fn.sh "$INFO")
  sketchybar --set "$NAME" label="$INFO" icon="$icon"
fi
