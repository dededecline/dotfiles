function secrets --description "Manage secrets from 1Password"
    set -l secrets_script "$HOME/.config/.system/setup/secrets.sh"

    if not test -f "$secrets_script"
        echo "Secrets script not found: $secrets_script"
        return 1
    end

    switch "$argv[1]"
        case check status
            bash "$secrets_script" --check
        case help -h --help
            echo "Usage: secrets [command]"
            echo ""
            echo "Commands:"
            echo "  (none)     Inject secrets from 1Password"
            echo "  check      Check which secrets are configured"
            echo "  help       Show this help message"
            echo ""
            echo "Prerequisites:"
            echo "  - 1Password CLI installed (brew install 1password-cli)"
            echo "  - Signed in to 1Password (op signin)"
        case ''
            bash "$secrets_script"
        case '*'
            echo "Unknown command: $argv[1]"
            echo "Run 'secrets help' for usage"
            return 1
    end
end
