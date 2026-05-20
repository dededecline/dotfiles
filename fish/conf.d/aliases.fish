# =============================================================================
# Aliases and Abbreviations
# Loaded automatically by Fish from conf.d/
# =============================================================================

# -----------------------------------------------------------------------------
# Abbreviations
# -----------------------------------------------------------------------------

# DevOps tools
abbr -a k kubectl
abbr -a tf tofu

# Editor
abbr -a vim nvim

# Language tools
abbr -a pip pip3
abbr -a python python3

# Modern CLI replacements (cat is a function that uses glow for markdown)
abbr -a diff delta
abbr -a du dust
abbr -a fetch fastfetch
abbr -a top btop

# Common commands
abbr -a ll "ls -la"
abbr -a la "ls -a"
abbr -a l "ls -l"

# Git shortcuts
abbr -a gs "git status"
abbr -a gb "git branch"
abbr -a gc "git checkout"
abbr -a gd "git diff"
abbr -a ga "git add"
abbr -a gp "git push"
abbr -a gl "git pull"
abbr -a gst "git stash"
abbr -a gpop "git stash pop"

# -----------------------------------------------------------------------------
# Aliases (for complex commands that shouldn't expand)
# -----------------------------------------------------------------------------

# Modern CLI replacements
alias ls="lsd"
alias find="fd"
alias ping="gping"

# Utility commands
alias search="grep -rnw . -e"
alias tofulint="tofu fmt && tofu validate"

# Config editing
alias fishconfig="nvim ~/.config/fish/config.fish"

# Work-specific
alias preview='spacectl stack preview --sha (git rev-parse HEAD 2>/dev/null)'
alias spacelogin="spacectl profile login && tofu login spacelift.io"
alias lrl="/opt/homebrew/bin/lrl"

# Dotfiles management
alias dotfiles="cd ~/.config"

# Kubernetes quick context check
alias kctx="kubectl config current-context"
