function claude --wraps claude --description 'Claude Code wrapper with SSH keychain unlock'
    if set -q SSH_CONNECTION; or set -q SSH_TTY
        security unlock-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null
    end
    command claude $argv
end
