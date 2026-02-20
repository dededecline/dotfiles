# Work CLI additions for Brewfile
# Injected from 1Password - do not edit directly
# Run: secrets (or ~/.config/setup/secrets.sh)

# =============================================================================
# Work Taps
# =============================================================================
tap "{{ op://Employee/brew-ephemeral-env/tap }}"
tap "{{ op://Employee/brew-incident-mgmt/tap }}"
tap "{{ op://Employee/brew-infra-cd/tap }}"
tap "{{ op://Employee/brew-secure-access/tap }}"
tap "{{ op://Employee/brew-internal-cli/tap }}"

# =============================================================================
# Work CLI Tools
# =============================================================================
brew "{{ op://Employee/brew-ephemeral-env/formula }}"   # Ephemeral environments
brew "{{ op://Employee/brew-incident-mgmt/formula }}"   # Incident management
brew "{{ op://Employee/brew-infra-cd/formula }}"        # Infrastructure CD
brew "{{ op://Employee/brew-secure-access/formula }}"   # Secure access

# =============================================================================
# Work Tools (public formulas)
# =============================================================================
brew "{{ op://Employee/brew-ci-tool/formula }}"         # CI runner
brew "{{ op://Employee/brew-db-cli/formula }}"          # Database CLI
brew "{{ op://Employee/brew-k8s-cd/formula }}"          # Kubernetes CD

# =============================================================================
# Work Applications (casks)
# =============================================================================
cask "{{ op://Employee/brew-internal-cli/cask }}"         # Internal CLI
