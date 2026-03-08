#!/bin/bash

# Aerospace workspace configuration for sketchybar
# Creates workspace items that show open applications as icons

# Detect number of connected displays
display_count=$(system_profiler SPDisplaysDataType | grep -c "Resolution:")

# Get all workspaces across all monitors, then sort numerically for proper ordering
all_workspaces=$(for monitor in $(aerospace list-monitors --format "%{monitor-appkit-nsscreen-screens-id}"); do
  aerospace list-workspaces --monitor "$monitor"
done | sort -n | uniq)

# Parse workspace-to-monitor assignments from aerospace.toml
secondary_workspaces=""
aerospace_config="$CONFIG_DIR/../aerospace/aerospace.toml"
in_section=false
while IFS= read -r line; do
  if [[ "$line" =~ ^\[workspace-to-monitor-force-assignment\] ]]; then
    in_section=true
    continue
  fi
  if $in_section && [[ "$line" =~ ^\[ ]]; then
    break
  fi
  if $in_section && [[ "$line" =~ ^([0-9]+)[[:space:]]*= ]]; then
    ws="${BASH_REMATCH[1]}"
    first_val=$(echo "$line" | sed -nE 's/.*=[[:space:]]*\[?[[:space:]]*"([^"]*)".*/\1/p')
    if [ "$first_val" = "secondary" ]; then
      secondary_workspaces="$secondary_workspaces $ws"
    fi
  fi
done <"$aerospace_config"

for sid in $all_workspaces; do
  # Use parsed mapping; default to display 1; skip lookup on single display
  display_id="1"
  if [ "$display_count" -ge "2" ] && [[ " $secondary_workspaces " == *" $sid "* ]]; then
    display_id="2"
  fi

  sketchybar --add item space.$sid left \
    --set space.$sid \
    display="$display_id" \
    drawing=on \
    background.color=$ITEM_BG_COLOR \
    background.corner_radius=5 \
    background.drawing=on \
    background.border_color=$OVERLAY0 \
    background.border_width=0 \
    background.height=26 \
    icon="$sid" \
    icon.color=$TEXT \
    icon.font="$NERD_FONT:Bold:14.0" \
    icon.padding_left=10 \
    icon.padding_right=6 \
    label.font="sketchybar-app-font:Regular:14.0" \
    label.color=$SUBTEXT0 \
    label.padding_right=0 \
    label.padding_left=0 \
    label.y_offset=-1 \
    click_script="aerospace workspace $sid" \
    script="$PLUGIN_DIR/aerospace.sh $sid" \
    --subscribe space.$sid aerospace_workspace_change
done

# Load initial icons for all workspaces with windows
for monitor in $(aerospace list-monitors); do
  for sid in $(aerospace list-workspaces --monitor "$monitor" --empty no); do
    apps=$(aerospace list-windows --workspace "$sid" | awk -F'|' '{gsub(/^ *| *$/, "", $2); print $2}')

    sketchybar --set space.$sid drawing=on

    if [ "${apps}" != "" ]; then
      icon_strip=" "
      while read -r app; do
        icon_strip+=" $($CONFIG_DIR/plugins/icon_map_fn.sh "$app")"
      done <<<"${apps}"
      sketchybar --set space.$sid label="$icon_strip" label.padding_right=14
    fi
  done
done
