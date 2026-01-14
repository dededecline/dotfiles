# Work CLI additions for Brewfile
# Injected from 1Password - do not edit directly
# Run: secrets (or ~/.config/setup/secrets.sh)

# =============================================================================
# Work Taps
# =============================================================================
tap "{{ op://Private/brew-ephemeral-env/tap }}"
tap "{{ op://Private/brew-incident-mgmt/tap }}"
tap "{{ op://Private/brew-infra-cd/tap }}"
tap "{{ op://Private/brew-secure-access/tap }}"

# =============================================================================
# Work CLI Tools
# =============================================================================
brew "{{ op://Private/brew-ephemeral-env/formula }}"   # Ephemeral environments
brew "{{ op://Private/brew-incident-mgmt/formula }}"   # Incident management
brew "{{ op://Private/brew-infra-cd/formula }}"        # Infrastructure CD
brew "{{ op://Private/brew-secure-access/formula }}"   # Secure access

# =============================================================================
# Work Tools (public formulas)
# =============================================================================
brew "{{ op://Private/brew-ci-tool/formula }}"         # CI runner
brew "{{ op://Private/brew-db-cli/formula }}"          # Database CLI
brew "{{ op://Private/brew-k8s-cd/formula }}"          # Kubernetes CD
