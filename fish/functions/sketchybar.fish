# Sketchybar helper commands
# Usage: sketchybar [reload|restart|stop|start]

function sketchybar --description "Sketchybar management commands"
    set -l plist "$HOME/Library/LaunchAgents/com.felixkratz.sketchybar.plist"

    switch "$argv[1]"
        case reload
            command sketchybar --reload
            echo "Sketchybar config reloaded"
        case restart
            launchctl unload "$plist" 2>/dev/null
            launchctl load "$plist"
            echo "Sketchybar restarted"
        case stop
            launchctl unload "$plist"
            echo "Sketchybar stopped"
        case start
            launchctl load "$plist"
            echo "Sketchybar started"
        case ""
            # Pass through to actual sketchybar command for any other args
            command sketchybar $argv
        case "*"
            # Pass through to actual sketchybar command for any other args
            command sketchybar $argv
    end
end
