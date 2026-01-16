#!/bin/bash

# Install all prerequisites for ai-tooling
# This script installs all tools required to run Claude Code with MCP servers and custom skills

set -e  # Exit on error

echo "Installing ai-tooling prerequisites..."

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Error: Homebrew is not installed. Please install from https://brew.sh"
    exit 1
fi

# Check if HOMEBREW_GITHUB_API_TOKEN is set (required by lrl tap)
if [ -z "$HOMEBREW_GITHUB_API_TOKEN" ]; then
    echo ""
    echo "⚠️  HOMEBREW_GITHUB_API_TOKEN is not set"
    echo ""
    echo "The 'lrl' package may require a GitHub API token to install."
    echo "If installation fails, set it up:"
    echo "  1. Create a GitHub token at: https://github.com/settings/tokens"
    echo "  2. Add to your shell profile (~/.zshrc or ~/.bashrc):"
    echo "     export HOMEBREW_GITHUB_API_TOKEN='your_token_here'"
    echo "  3. Run: source ~/.zshrc  (or restart your terminal)"
    echo ""
    echo "For more info: https://github.com/pinginc/homebrew-lrl?tab=readme-ov-file#install-via-homebrew"
    echo ""
    echo "Continuing with installation..."
    echo ""
fi

# Install all Homebrew dependencies using Brewfile
echo "Installing Homebrew packages from Brewfile..."
if [ -f "Brewfile" ]; then
    if brew bundle --file=Brewfile 2>&1; then
        echo "✓ All Homebrew packages installed"
    else
        echo ""
        echo "⚠️  Some packages failed to install via Brewfile. Installing individually..."
        echo ""

        # Install core packages individually
        for package in go-task jq gettext node go argocd; do
            if ! command -v "$package" &> /dev/null; then
                echo "Installing $package..."
                if brew install "$package" 2>&1; then
                    echo "✓ $package installed"
                else
                    echo "✗ Failed to install $package"
                fi
            else
                echo "✓ $package already installed"
            fi
        done

        # Try to install lrl separately
        if ! command -v lrl &> /dev/null; then
            echo "Installing lrl from pinginc/lrl..."
            if brew tap pinginc/lrl 2>&1 && brew install lrl 2>&1; then
                echo "✓ lrl installed"
            else
                echo "⚠️  Failed to install lrl"
                echo "   You may need to install it manually: brew tap pinginc/lrl && brew install lrl"
                echo "   For help, message #ask-time-owls-infrastructure"
            fi
        else
            echo "✓ lrl already installed"
        fi

        # Try to install zli separately
        if ! command -v zli &> /dev/null; then
            echo "Installing zli from bastionzero/tap..."
            if brew install bastionzero/tap/zli 2>&1; then
                echo "✓ zli installed"
            else
                echo "⚠️  Failed to install zli"
            fi
        else
            echo "✓ zli already installed"
        fi

        # Try to install 1password-cli cask separately
        if ! command -v op &> /dev/null; then
            echo "Installing 1password-cli..."
            if brew install --cask 1password-cli 2>&1; then
                echo "✓ 1password-cli installed"
            else
                echo "⚠️  Failed to install 1password-cli"
            fi
        else
            echo "✓ 1password-cli already installed"
        fi
    fi
else
    echo "Error: Brewfile not found in current directory"
    exit 1
fi

# Link gettext to ensure envsubst is available
if command -v envsubst &> /dev/null; then
    echo "✓ envsubst available"
else
    echo "Linking gettext..."
    brew link --force gettext
fi

# Claude Code CLI (npm package - not in Brewfile)
if ! command -v claude &> /dev/null; then
    echo "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
else
    echo "✓ Claude Code CLI already installed"
fi

# Check if Go bin directory is in PATH
echo ""
echo "Checking Go installation and PATH configuration..."
if command -v go &> /dev/null; then
    GO_BIN_PATH="$(go env GOPATH)/bin"

    if [[ ":$PATH:" != *":$GO_BIN_PATH:"* ]]; then
        echo ""
        echo "⚠️  Go bin directory is not in your PATH"
        echo ""
        echo "Go binaries are installed to: $GO_BIN_PATH"
        echo "To use Go-installed tools (like Observe CLI), add this to your shell profile:"
        echo ""
        echo "  # For Zsh (default on macOS), add to ~/.zshrc:"
        echo "  export PATH=\"\$PATH:$GO_BIN_PATH\""
        echo ""
        echo "  # For Bash, add to ~/.bashrc or ~/.bash_profile:"
        echo "  export PATH=\"\$PATH:$GO_BIN_PATH\""
        echo ""
        echo "Then restart your terminal or run: source ~/.zshrc"
        echo ""
    else
        echo "✓ Go bin directory is in PATH"
    fi

    # Install Observe CLI
    if ! command -v observe &> /dev/null; then
        echo "Installing Observe CLI..."
        if go install github.com/observeinc/observe@latest 2>&1; then
            echo "✓ Observe CLI installed to $GO_BIN_PATH/observe"

            # Check again if it's in PATH after installation
            if ! command -v observe &> /dev/null; then
                echo ""
                echo "⚠️  Observe CLI was installed but is not in your PATH"
                echo "   Add $GO_BIN_PATH to your PATH (see instructions above)"
                echo "   Then restart your terminal"
            fi
        else
            echo "✗ Failed to install Observe CLI"
            echo "  You may need to install it manually: go install github.com/observeinc/observe@latest"
        fi
    else
        echo "✓ Observe CLI already installed"
    fi
else
    echo "⚠️  Go is not installed. This shouldn't happen - check Brewfile installation"
fi

echo ""
echo "✓ All prerequisites installed successfully!"
echo ""

# Generate .env from 1Password vault
echo "Generating .env from 1Password vault..."
if [ -f .env.template ]; then
    if command -v op >/dev/null 2>&1; then
        if op account list >/dev/null 2>&1; then
            if op inject -i .env.template -o .env 2>/dev/null; then
                if [ -f .env ] && [ -s .env ]; then
                    echo "[+] Generated .env from 1Password"
                else
                    echo "[!] .env file was not created or is empty"
                    echo "    Check your .env.template format and 1Password vault"
                    echo "    Run 'task env' to try again"
                fi
            else
                echo "[!] Failed to generate .env from 1Password"
                echo "    Possible causes:"
                echo "    - Invalid .env.template format"
                echo "    - Missing secrets in 1Password vault"
                echo "    - Incorrect vault references"
                echo "    Run 'task env' to try again or check 'op inject --help'"
            fi
        else
            echo "[!] Not signed into 1Password. Run: eval \$(op signin)"
            echo "    Then run 'task env' to generate .env"
        fi
    else
        echo "[!] 1Password CLI not installed (this shouldn't happen)"
        echo "    Run 'task env' to try again"
    fi
else
    echo "[!] .env.template not found - skipping .env generation"
    echo "    If you have a .env.template, run 'task env' to generate .env"
fi

echo ""
echo "Next step:"
echo "Run 'task recommended' to install Claude Code settings, MCP servers, agents, and skills"