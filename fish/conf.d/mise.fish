# mise - Dev tool version manager
# Activated from conf.d/ for automatic per-project tool version switching
if type -q mise
    set -gx MISE_TRUSTED_CONFIG_PATHS $HOME
    mise activate fish | source
end
