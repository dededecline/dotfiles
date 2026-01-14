#!/bin/bash

# Front app item - shows currently focused application
# Styled with Catppuccin Frappe lavender accent

source "$CONFIG_DIR/colors.sh"

front_app=(
  icon.drawing=on
  icon.font="sketchybar-app-font:Regular:16.0"
  icon.color=$LAVENDER
  icon.padding_left=10
  icon.padding_right=4
  label.font="$FONT:Bold:13.0"
  label.color=$LAVENDER
  label.padding_right=10
  background.color=$FRONT_APP_BG
  background.corner_radius=5
  background.height=26
  background.drawing=on
  background.border_color=$LAVENDER
  background.border_width=2
  display=active
  script="$PLUGIN_DIR/front_app.sh"
  click_script="open -a 'Mission Control'"
  padding_left=10
)

sketchybar --add item front_app left \
  --set front_app "${front_app[@]}" \
  --subscribe front_app front_app_switched
