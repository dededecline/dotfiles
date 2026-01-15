# Refresh configured processes and services
# Usage: refresh [all|fish|aerospace|sketchybar|tmux|help]

function refresh --description "Reload configured processes and services"
    switch "$argv[1]"
        case all ""
            # Reload everything
            echo "Refreshing all configured processes..."

            # Fish shell
            source ~/.config/fish/config.fish
            echo "✓ Fish config reloaded"

            # Aerospace window manager
            if command -q aerospace
                aerospace reload-config 2>/dev/null
                echo "✓ Aerospace config reloaded"
                # Wait for aerospace to settle before reloading sketchybar
                sleep 0.5
            end

            # Sketchybar status bar
            if command -q sketchybar
                sketchybar --reload 2>/dev/null
                echo "✓ Sketchybar config reloaded"
            end

            # Tmux (only if in a tmux session)
            if set -q TMUX
                tmux source ~/.config/tmux/tmux.conf 2>/dev/null
                echo "✓ Tmux config reloaded"
            end

            echo "All processes refreshed"

        case fish
            source ~/.config/fish/config.fish
            echo "Fish config reloaded"

        case aerospace
            if command -q aerospace
                aerospace reload-config 2>/dev/null
                echo "Aerospace config reloaded"
            else
                echo "Aerospace not found"
                return 1
            end

        case sketchybar
            if command -q sketchybar
                sketchybar --reload 2>/dev/null
                echo "Sketchybar config reloaded"
            else
                echo "Sketchybar not found"
                return 1
            end

        case tmux
            if command -q tmux
                if set -q TMUX
                    tmux source ~/.config/tmux/tmux.conf 2>/dev/null
                    echo "Tmux config reloaded"
                else
                    echo "Not currently in a tmux session"
                    return 1
                end
            else
                echo "Tmux not found"
                return 1
            end

        case help -h --help
            echo "Usage: refresh [command]"
            echo ""
            echo "Commands:"
            echo "  (none)       Reload all configured processes"
            echo "  all          Reload all configured processes"
            echo "  fish         Reload Fish shell config"
            echo "  aerospace    Reload Aerospace window manager config"
            echo "  sketchybar   Reload Sketchybar status bar config"
            echo "  tmux         Reload Tmux config (if in tmux session)"
            echo "  help         Show this help message"
            echo ""
            echo "Examples:"
            echo "  refresh              # Reload everything"
            echo "  refresh fish         # Reload just Fish config"
            echo "  refresh aerospace    # Reload just Aerospace"

        case '*'
            echo "Unknown command: $argv[1]"
            echo "Run 'refresh help' for usage"
            return 1
    end
end
