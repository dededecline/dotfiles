# =============================================================================
# Fish Shell Configuration
# Main entry point - PATH and aliases are in conf.d/ for modularity
# =============================================================================

# Environment Variables
set -g fish_greeting
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx DOTFILES $HOME/.config
set -gx SHELL (command -s fish)

# FZF Catppuccin Frappe colors
set -gx FZF_DEFAULT_OPTS "\
--color=bg+:#414559,bg:#303446,spinner:#f2d5cf,hl:#e78284 \
--color=fg:#c6d0f5,header:#e78284,info:#ca9ee6,pointer:#f2d5cf \
--color=marker:#f2d5cf,fg+:#c6d0f5,prompt:#ca9ee6,hl+:#e78284"

# =============================================================================
# Starship Prompt
# =============================================================================
if type -q starship
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
