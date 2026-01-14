# =============================================================================
# Aliases and Abbreviations
# Loaded automatically by Fish from conf.d/
# =============================================================================

# -----------------------------------------------------------------------------
# Abbreviations (expand as you type - preferred for simple commands)
# -----------------------------------------------------------------------------

# DevOps tools
abbr -a k kubectl
abbr -a tf tofu

# Editor
abbr -a vim nvim

# Language tools
abbr -a pip pip3
abbr -a python python3

# Modern CLI replacements
abbr -a cat bat
abbr -a diff difft
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
alias vim="nvim"

# Utility commands
alias search="grep -rnw . -e"
alias tofulint="tofu fmt && tofu validate"

# Config editing
alias fishconfig="nvim ~/.config/fish/config.fish"

# Work-specific
alias preview='spacectl stack preview --sha (git rev-parse HEAD 2>/dev/null)'
alias spacelogin="spacectl profile login && terraform login spacelift.io"

# Dotfiles management
alias dotfiles="cd ~/.config"
alias reload="source ~/.config/fish/config.fish"

# Kubernetes quick context check
alias kctx="kubectl config current-context"
