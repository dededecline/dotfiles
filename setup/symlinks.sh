#!/usr/bin/env bash
#
# symlinks.sh - Create symlinks from ~ to ~/.config
#

DOTFILES="$HOME/.config"
TEMPLATES_DIR="$DOTFILES/templates"

# Function to process a template with environment variable substitution
process_template() {
    local template="$1"
    local output="$2"

    if [[ ! -f "$template" ]]; then
        echo "  Skipped: $template (not found)"
        return 1
    fi

    mkdir -p "$(dirname "$output")"
    envsubst < "$template" > "$output"
    echo "  Generated: $output"
}

# Function to create symlink safely
create_symlink() {
    local source="$1"
    local target="$2"

    # Skip if source doesn't exist
    if [[ ! -e "$source" ]]; then
        echo "  Skipped: $source (not found)"
        return
    fi

    # If target is already a symlink pointing to the right place, skip
    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
        echo "  OK: $target"
        return
    fi

    # Remove existing symlink
    if [[ -L "$target" ]]; then
        rm "$target"
    # Backup existing file
    elif [[ -f "$target" ]]; then
        echo "  Backing up: $target -> ${target}.backup"
        mv "$target" "${target}.backup"
    fi

    ln -s "$source" "$target"
    echo "  Created: $target -> $source"
}

echo "Creating symlinks..."

# Git configuration
create_symlink "$DOTFILES/git/config" "$HOME/.gitconfig"

# Sensitive files (if they exist)
create_symlink "$DOTFILES/sensitive/.npmrc" "$HOME/.npmrc"

# Process templates (non-secret configs that need $HOME expansion)
echo "Processing templates..."
process_template "$TEMPLATES_DIR/glow.yml.tpl" "$DOTFILES/glow/glow.yml"

# macOS app configs (these apps don't respect XDG_CONFIG_HOME)
mkdir -p "$HOME/Library/Preferences/glow"
create_symlink "$DOTFILES/glow/glow.yml" "$HOME/Library/Preferences/glow/glow.yml"

echo "Symlinks complete!"
