#!/usr/bin/env bash
#
# Generate SSH key pair for GitHub
#

echo "=========================================="
echo "  SSH Key Setup"
echo "=========================================="
echo ""

# Get email
read -p "Enter your email address: " email

if [[ -z "$email" ]]; then
  echo "Error: Email is required"
  exit 1
fi

SSH_KEY="$HOME/.ssh/id_ed25519"

# Check if key already exists
if [[ -f "$SSH_KEY" ]]; then
  echo ""
  echo "SSH key already exists at $SSH_KEY"
  read -p "Overwrite? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborting."
    exit 0
  fi
fi

# Generate key
echo ""
echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY"

# Start SSH agent
eval "$(ssh-agent -s)"

# Create/update SSH config
mkdir -p "$HOME/.ssh"
if ! grep -q "Host \*" "$HOME/.ssh/config" 2>/dev/null; then
  cat >>"$HOME/.ssh/config" <<EOF

Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
EOF
  echo "Updated ~/.ssh/config"
fi

# Add key to keychain
ssh-add --apple-use-keychain "$SSH_KEY"

echo ""
echo "=========================================="
echo "  SSH Key Generated!"
echo "=========================================="
echo ""
echo "Copy this public key to GitHub:"
echo "  https://github.com/settings/ssh/new"
echo ""
cat "${SSH_KEY}.pub"
echo ""
echo ""
echo "Or copy to clipboard with:"
echo "  pbcopy < ${SSH_KEY}.pub"
echo ""
