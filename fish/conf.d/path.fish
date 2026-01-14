# =============================================================================
# PATH Configuration
# Loaded automatically by Fish from conf.d/
# =============================================================================

# Homebrew (must be first for Apple Silicon)
fish_add_path /opt/homebrew/bin
fish_add_path /opt/homebrew/sbin

# Dotfiles bin directory
fish_add_path $HOME/.config/bin

# Language runtimes
fish_add_path $HOME/go/bin
fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/.local/bin

# Tool-specific paths
fish_add_path $HOME/.yarn/bin
fish_add_path $HOME/.lmstudio/bin

# Project-specific paths (add your own in config.local.fish)
