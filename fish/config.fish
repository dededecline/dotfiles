# =============================================================================
# Fish Shell Configuration
# Main entry point
# PATH and aliases are in conf.d/ for modularity
# =============================================================================

# Environment Variables
set -g fish_greeting
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx DOTFILES $HOME/.config
set -gx SHELL (command -s fish)
set -gx CLAUDE_CONFIG_DIR $HOME/.config/claude
set -gx CODEX_HOME $HOME/.config/codex
set -l npm_token (security find-generic-password -a "$USER" -s "npm_token" -w 2>/dev/null)
test -n "$npm_token" && set -gx NPM_TOKEN $npm_token
set -l github_pat (cat $HOME/.config/.system/sensitive/github-pat 2>/dev/null)
test -n "$github_pat" && set -gx GITHUB_PERSONAL_ACCESS_TOKEN $github_pat

# @theme:start
# FZF Catppuccin Frappe colors
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#414559,bg:#303446,spinner:#f2d5cf,hl:#e78284 \
--color=fg:#c6d0f5,header:#e78284,info:#ca9ee6,pointer:#f2d5cf \
--color=marker:#f2d5cf,fg+:#c6d0f5,prompt:#ca9ee6,hl+:#e78284"
# @theme:end

# =============================================================================
# Starship Prompt
# =============================================================================
if type -q starship
    set -gx STARSHIP_CONFIG $DOTFILES/starship/starship.toml
    starship init fish | source
end

# =============================================================================
# Tool Integrations
# =============================================================================

# FZF keybindings
if type -q fzf
    fzf --fish | source
end

# Atuin shell history
if type -q atuin
    atuin init fish | source
end

# =============================================================================
# Fastfetch on startup (interactive shells only)
# =============================================================================
if status is-interactive; and type -q fastfetch
    fastfetch
end

# =============================================================================
# Local overrides (not tracked in git)
# =============================================================================
if test -f ~/.config/fish/config.local.fish
    source ~/.config/fish/config.local.fish
end
