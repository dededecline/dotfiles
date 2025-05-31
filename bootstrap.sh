#!/bin/sh

set -e

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
template_file="$script_dir/home/.chezmoiscripts/darwin/run_onchange_before_install-packages.sh.tmpl"

# macOS Setup
# Installs homebrew, xcode developer tools, and rosetta 2
if [ "$(uname)" = "Darwin" ]; then
  if [ ! "$(command -v brew)" ]; then
    # This will also install xcode developer tools if not already installed
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if ! pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
    softwareupdate --install-rosetta --agree-to-license
  fi
  if [ ! "$(command -v chezmoi)" ]; then
    /opt/homebrew/bin/brew install chezmoi
    if ! grep -q '"chezmoi"' "$template_file"; then
      sed -i '' '/{{ \$brews := list/a\
     "chezmoi"' "$template_file"
    fi
  fi
  if [ ! "$(command -v mas)" ]; then
    /opt/homebrew/bin/brew install mas
    if ! grep -q '"mas"' "$template_file"; then
      sed -i '' '/{{ \$brews := list/a\
     "mas"' "$template_file"
    fi
  fi
fi

echo "export PATH=/opt/homebrew/bin:$PATH" >> ~/.zshrc && source ~/.zshrc

# exec: replace current process with chezmoi init
exec /opt/homebrew/bin/chezmoi init --apply "--source=$script_dir"
/opt/homebrew/bin/cutler apply
