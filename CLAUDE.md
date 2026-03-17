
  # CLAUDE.md                                                                 
                                                                              
  This file provides guidance to Claude Code (claude.ai/code) when working    
  with code in this repository.                                               
                                                                              
  ## Overview                                                                 
                                                                              
  This is a macOS dotfiles repository managed as a git repo in ~/.config. It  
  uses Fish shell as the primary shell with Starship prompt and Catppuccin    
  Frappe theming throughout.                                                  
                                                                              
  ## Key Commands                                                             
                                                                              
  ### Setup & Bootstrap                                                       
                                                                              
    # Fresh machine (one-liner)                                               
    curl -fsSL https://raw.githubusercontent.                                 
                                                                              
  com/dededecline/dotfiles/main/setup.sh | bash                               
                                                                              
    # Local setup                                                             
    ./setup.sh              # Run full setup (idempotent)
    ./setup.sh --brew       # Sync Homebrew packages only (declarative with --

  cleanup)
  ./setup.sh --hostname nyx # Override hostname for testing
  ./setup.sh --macos      # Apply macOS system preferences only               
                                                                              
  ### Secrets Management (1Password)                                          
                                                                              
    secrets                         # Inject all secrets from 1Password       
    secrets check                   # Check which secrets are configured      
    ~/.config/.system/setup/secrets.sh --check  # Same as above (bash)
                                                                              
  ### Symlinks Only                                                           
                                                                              
    source ~/.config/.system/setup/symlinks.sh  # Just create symlinks
                                                                              
  ### Theme Sync

    ./.system/setup/sync-theme.sh          # Sync theme colors to all tool configs

  Theme is defined in `.system/themes/theme.toml` (flavor + accent). The sync script
  reads the palette and updates all downstream configs automatically. Runs
  during full setup.

  ### Fish Shell

    refresh                         # Reload all configured processes         
    refresh fish                    # Reload fish config only                 
    refresh aerospace               # Reload aerospace config only            
    refresh sketchybar              # Reload sketchybar config only           
    fishconfig                      # Edit fish config in nvim                
                                                                              
  ## Architecture                                                             
                                                                              
  ### Setup Script                                                            
                                                                              
  The setup.sh script is fully idempotent - run it anytime to ensure          
  everything                                                                  
  is configured:                                                              
                                                                              
  • Installs Xcode CLT and Homebrew (if missing)                              
  • Clones dotfiles repository (if missing)                                   
  • Injects secrets from 1Password (if authenticated)                         
  • Syncs Homebrew packages (declarative with --cleanup)
  • Syncs theme colors to all tool configs
  • Generates Claude settings from machine-filtered JSONC
  • Creates symlinks
  • Configures Fish shell as default                                          
  • Installs Fisher and TPM                                 
  • Applies macOS system preferences                                          
                                                                              
  Use --brew or --macos flags to run only those specific tasks.               
                                                                              
  ### macOS Preferences                                                       
                                                                              
  The .system/macos/.macos script sets system defaults via defaults write commands:         
                                                                              
  • **UI**: Dark mode, auto-hide menu bar, expanded save panels               
  • **Input**: Key repeat enabled, smart punctuation disabled, auto-correct   
  disabled                                                                    
  • **Finder**: POSIX path in title, hidden files visible, no desktop icons   
  • **Screenshots**: PNG format, no shadow, saves to clipboard                
  • **Sound**: System beep disabled                                           
  • **Trackpad**: Tap to click disabled                                       
  • **Security**: Touch ID for sudo authentication                            
                                                                              
  Run standalone with ./setup.sh --macos.                                     
                                                                              
  ### Homebrew Management

  Homebrew packages are managed declaratively with brew bundle --cleanup.
  Packages are organized under `.system/profiles/`:

  ```
  .system/profiles/
  ├── profiles.toml            # Machine-to-group membership (sole source of truth)
  ├── labels/
  │   ├── all/Brewfile         # All machines
  │   ├── laptop/Brewfile      # Laptop machines
  │   ├── personal/Brewfile    # Personal machines
  │   ├── infra/Brewfile       # Infrastructure machines
  │   ├── server/Brewfile      # Server machines
  │   └── work/Brewfile        # Work group
  └── machines/
      ├── hera/Brewfile        # hera only
      ├── athena/Brewfile      # athena only
      └── nyx/Brewfile         # nyx only
  ```

  Machine-to-group membership is defined in `.system/profiles/profiles.toml`
  (TOML: `[hostname]` section with `groups = [...]`). Adding a new machine or
  group requires only editing `profiles.toml` and optionally adding a
  labels Brewfile directory.

  `profiles.toml` is the sole source of truth for defining machines and machine groups. The `work` group gates 1Password work-account integration and work secrets. Work packages live in `machines/hera/Brewfile` since hera is the only work machine.
                                                                              
  ### Secrets System                                                          
                                                                              
  The secrets system uses 1Password CLI (op inject) to populate sensitive     
  values:                                                                     
                                                                              
  1. **Templates** (.system/templates/*.tpl) - Files with {{ op://Vault/Item/Field }}
  references
  2. **secrets.sh** - Processes templates and writes to .system/sensitive/ directory
  3. **.system/sensitive/** - Gitignored directory containing injected credentials    
                                                                              
  To add a new secret:                                                        
                                                                              
  1. Create a template in .system/templates/ with op:// references
  2. Add injection logic to .system/setup/secrets.sh
  3. Document the required 1Password item in .system/templates/README.md              
                                                                              
  ### Symlinks                                                                
                                                                              
  Traditional dotfiles that expect ~/. are symlinked:                         
                                                                              
  • git/config → ~/.gitconfig                                                 
  • .system/sensitive/.npmrc → ~/.npmrc                                               
                                                                              
  ### Display Monitor System

  Automatically detects display connection/disconnection and reloads
  aerospace and sketchybar configurations. Runs as a LaunchAgent that checks
  every 3 seconds.

  Monitor definitions (resolution, refresh rate, serial, arrangement) are
  configured in `.system/profiles/displays.toml`. The `display-profiles.sh`
  script reads this TOML and builds displayplacer commands generically.

  To add a new monitor: add a `[name]` section to `displays.toml` with
  `serial`, `res`, `hz`, `color_depth`, and `dual_origin` keys. The
  `builtin` section is special (no serial; detected at runtime).

  Components:
  • .system/profiles/displays.toml - Monitor definitions (resolution, serial, layout)
  • .system/setup/display-profiles.sh - Data-driven display profile application
  • .system/setup/monitor-watcher.sh - Detects display count changes using
  system_profiler
  • .system/setup/reload-display-config.sh - Reloads configs when changes detected
  • .system/templates/display-monitor.plist.tpl - LaunchAgent configuration

  The system logs to ~/.config/logs/display-monitor.log and is automatically
  loaded by setup.sh if aerospace and sketchybar are installed.

  ### Spotlight Shortcuts LaunchAgent

  macOS re-enables Spotlight keyboard shortcuts on every restart. A
  LaunchAgent runs .system/setup/disable-spotlight-shortcuts.sh at login to
  re-disable shortcuts 64, 65, and 160, preventing conflicts with Raycast.

  Components:
  • .system/setup/disable-spotlight-shortcuts.sh - Disables shortcuts via defaults
  write and activateSettings
  • .system/templates/spotlight-shortcuts.plist.tpl - LaunchAgent configuration

  The script waits 10 seconds for macOS to finish boot-time restoration,
  then applies the settings. Logs to ~/.config/logs/spotlight-shortcuts.log.

  ### Theme System

  Theme colors are centralized via `.system/themes/theme.toml` (flavor + accent) and
  `.system/themes/catppuccin-frappe/palette.toml` (hex values). The sync script
  (`.system/setup/sync-theme.sh`) propagates colors to all tool configs:

  - **Generated files**: sketchybar/colors.sh, lsd/colors.yaml,
  atuin/themes/*.toml (full regeneration)
  - **Section markers**: starship/starship.toml, fish/config.fish,
  fastfetch/config.jsonc, .system/templates/git-config.tpl (content between
  `@theme:start`/`@theme:end` replaced)
  - **Flavor strings**: nvim, tmux, bat, atuin, kitty (flavor name updated)
  - **Upstream files**: kitty.conf, bat.tmTheme, glow, zed themes (manual
  download for flavor changes)

  To change themes: edit `.system/themes/theme.toml`, run `.system/setup/sync-theme.sh`.

  ### Claude Settings

  `claude/settings.jsonc` is the source of truth for Claude Code settings.
  `claude/settings.json` is generated by `setup.sh` using `@machine:<name>`
  / `@end:<name>` markers. Markers accept hostnames or group names:
  • `// @machine:hera` — only on hera
  • `// @machine:laptop` — on hera + athena
  • `// @machine:personal` — on athena + nyx

  To modify settings: edit `claude/settings.jsonc`, then run `./setup.sh`.

  ### Kitty Fonts

  Kitty on macOS has known issues with Homebrew cask-installed fonts (fonts
  installed to ~/Library/Fonts/). Use NF (Nerd Font) cask variants that
  include patched glyphs and set `font_family` to the registered family name
  with `auto` for weight/style variants. The `symbol_map` for `Symbols Nerd
  Font Mono` provides fallback for any missing glyphs. Ligatures are enabled
  via `disable_ligatures never`.

  Always enable ligatures if the font supports them (`disable_ligatures
  never` in kitty.conf).

  Current font: `Maple Mono NF` (cask: `font-maple-mono-nf`)

  To change kitty's font:

  1. Add the font cask to Brewfile and run `brew bundle`
  2. Find the registered family name: `fc-list | grep "<font name>"`
  3. Set `font_family <Family Name>` in kitty/kitty.conf with `auto` for
  bold/italic/bold-italic variants
  4. Restart kitty (config reload alone may not pick up new fonts)

  ### Remote Access

  Remote desktop and SSH access from laptops (hera, athena) to server (nyx)
  via RustDesk over Tailscale.

  **Server (nyx):**
  - `brew "tailscale"` (CLI formula) — runs `tailscaled` daemon for Tailscale SSH
  - RustDesk server — configured by `.system/setup/rustdesk.sh` with permanent password
  - SSH restricted to Tailscale interface (`ListenAddress` set by `tailscale.sh`)
  - macOS Application Firewall enabled in stealth mode

  **Laptops (hera, athena):**
  - `cask "tailscale-app"` (GUI) — one-time manual step: Settings > Install CLI integration
  - RustDesk client — connect using Tailscale IP (100.x.x.x) or MagicDNS hostname

  **Scripts:**
  - `.system/setup/tailscale.sh` — enables Tailscale SSH, restricts SSH ListenAddress
  - `.system/setup/rustdesk.sh` — configures RustDesk for direct IP access

  **Manual steps — server (nyx):**
  - RustDesk: Accessibility, Screen Recording, Input Monitoring (System Settings > Privacy & Security)
  - Tailscale: `tailscale up` to authenticate, disable key expiry in admin console

  **Manual steps — laptops (hera, athena):**
  - Tailscale: Allow Network Extension when prompted, Settings > Install CLI integration

  **Claude Code auth:** Uses `apiKeyHelper` in `~/.claude/settings.json` to read
  the API key via a helper script. No env var or OAuth needed — works in both
  local and SSH sessions without Keychain access.
  - Helper script: `~/.config/.system/sensitive/claude-api-key-helper.sh`
    (reads `anthropic-api-key` from the same sensitive directory)
  - Config: `"apiKeyHelper"` in `claude/settings.jsonc` (source of truth;
    `setup.sh` generates `claude/settings.json` from it; does NOT work in `~/.claude.json`)

  ### Global Claude Instructions

  `claude/CLAUDE.global.md` is symlinked to `~/.claude/CLAUDE.md` and applies
  to all repos. It contains git workflow rules (no AI attribution, conventional
  commits for work repos, feature branch enforcement).

  ### Git Guard Hook

  `claude/assets/scripts/git-guard.sh` is a PreToolUse hook that enforces git
  workflow rules at the tool level:

  • **All repos**: Blocks `Co-Authored-By` trailers and `--author` overrides
  • **Pinginc repos**: Requires conventional commit format (`type: LINEAR-ID: description`)
  • **Pinginc repos**: Blocks pushing directly to main/master

  Pinginc repos are detected dynamically via `git remote -v`. The hook is
  registered in `claude/settings.jsonc` with no `@machine:` marker since the
  pinginc checks are runtime-gated.

  ### Fish Functions                                                          
                                                                              
  Custom functions in fish/functions/:                                        
                                                                              
  • refresh - Reload configured processes (aerospace, sketchybar, fish, tmux) 
  • secrets - Wrapper for secrets.sh                                          
  • gitdone - Switch to default branch and pull                               
  • clone - Clone work repos with archive detection                           
  • empty - Create empty commit with CI identity for triggering pipelines     
  • z - Connect to k8s clusters via ZLI (work, requires secrets)                                  
  • awsall - Run AWS CLI command across all profiles
                                                                              
  ### Key Aliases                                                             
                                                                              
  Modern CLI replacements (in fish/conf.d/aliases.fish):                      
                                                                              
  • ls → lsd, cat → bat, find → fd, diff → difft, top → btop                  
  • k → kubectl, tf → tofu, vim → nvim                                        
  • dotfiles - cd to ~/.config                                                
                                                                              
  ### Local Overrides                                                         
                                                                              
  Untracked files for machine-specific config:                                
                                                                              
  • ~/.config/fish/config.local.fish                                          
                                                                              
  ### Development Instructions                                                
                                                                              
  • Always protect the user's name, email address, place of work, and other   
  sensitive data behind templates and 1Password                               
  • Always check if CLAUDE.md, README.md, and/or Commands.md need updating    
  after making changes/updates                                                
  • Always make package/application changes programatically via homebrew      
  (ideally) or mas (if necessary)                                             
  • ALways develop idempotently                                               
  • Always add theming if possible. Currently, everything is themed to        
  Catppuccin Frappe with Lavender Accents                                     
  • Always attempt the simplest possible coding output solutions to a problem 
                                                                              
  • Always ensure that templated/protected files' generated output are
  excluded from commit in the gitignore

  ### Shell Script Quality (shellcheck)

  All shell scripts must pass shellcheck with zero warnings. Follow these
  practices:

  • **Quote variables**: Always double-quote `"$variable"` expansions to
  prevent word splitting and globbing (SC2086)
  • **Use `read -r`**: Always pass `-r` to `read` to prevent backslash
  mangling (SC2162)
  • **Group redirects**: When appending multiple commands to the same file,
  use `{ cmd1; cmd2; } >> file` instead of individual redirects (SC2129)
  • **Intentional single quotes**: When single quotes are correct (e.g.
  `envsubst '$HOME'` where the literal string must reach the command), add
  `# shellcheck disable=SC2016` with a brief explanation rather than
  "fixing" the quote style
  • **Disable directives**: Use inline `# shellcheck disable=SCXXXX` only
  for genuine false positives, always with a comment explaining why
