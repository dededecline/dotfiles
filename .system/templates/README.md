# Secret Templates

This directory contains template files with 1Password references.
The `.system/setup/secrets.sh` script uses `op inject` to populate these templates
with actual values from 1Password.

## Adding New Secrets

1. Create a new `.tpl` file in this directory
2. Use `{{ op://Vault/Item/Field }}` syntax for secret references
3. Add injection logic to `.system/setup/secrets.sh`
4. Update this README with setup instructions

### Adding New Claude Skills (Work-Specific)

For work-specific Claude skills:
1. Create the SKILL.md file locally
2. Upload to 1Password: `op document create SKILL.md --title "claude-skill-<name>" --vault "Private"`
3. Add the skill name mapping to `inject_claude_skills()` in `.system/setup/secrets.sh`
4. Add the skill to `.gitignore` under work-specific Claude skills

## Usage

```bash
# Inject all secrets from 1Password
~/.config/.system/setup/secrets.sh

# Check which secrets are configured
~/.config/.system/setup/secrets.sh --check

# Or use the fish function
secrets        # inject secrets
secrets check  # check status
```
