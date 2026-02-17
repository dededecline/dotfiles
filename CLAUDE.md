
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
  ./setup.sh --macos      # Apply macOS system preferences only               
                                                                              
  ### Secrets Management (1Password)                                          
                                                                              
    secrets                         # Inject all secrets from 1Password       
    secrets check                   # Check which secrets are configured      
    ~/.config/setup/secrets.sh --check  # Same as above (bash)                
                                                                              
  ### Symlinks Only                                                           
                                                                              
    source ~/.config/setup/symlinks.sh  # Just create symlinks                
                                                                              
  ### Theme Sync

    ./setup/sync-theme.sh          # Sync theme colors to all tool configs

  Theme is defined in `themes/theme.toml` (flavor + accent). The sync script
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
  • Creates symlinks
  • Configures Fish shell as default                                          
  • Installs Fisher and TPM                                 
  • Applies macOS system preferences                                          
                                                                              
  Use --brew or --macos flags to run only those specific tasks.               
                                                                              
  ### macOS Preferences                                                       
                                                                              
  The .macos script sets system defaults via defaults write commands:         
                                                                              
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
                                                                              
  Homebrew packages are managed declaratively with brew bundle --cleanup:     
                                                                              
  • Base packages defined in Brewfile                                         
  • Work packages in templates/Brewfile.tpl (injected via 1Password to        
  sensitive/Brewfile.work)                                                    
  • Combined at runtime before running brew bundle                            
  • --cleanup flag removes packages not in the combined Brewfile              
                                                                              
  ### Secrets System                                                          
                                                                              
  The secrets system uses 1Password CLI (op inject) to populate sensitive     
  values:                                                                     
                                                                              
  1. **Templates** (templates/*.tpl) - Files with {{ op://Vault/Item/Field }} 
  references                                                                  
  2. **secrets.sh** - Processes templates and writes to sensitive/ directory  
  3. **sensitive/** - Gitignored directory containing injected credentials    
                                                                              
  To add a new secret:                                                        
                                                                              
  1. Create a template in templates/ with op:// references                    
  2. Add injection logic to setup/secrets.sh                                  
  3. Document the required 1Password item in templates/README.md              
                                                                              
  ### Symlinks                                                                
                                                                              
  Traditional dotfiles that expect ~/. are symlinked:                         
                                                                              
  • git/config → ~/.gitconfig                                                 
  • sensitive/.npmrc → ~/.npmrc                                               
                                                                              
  ### Display Monitor System                                                  
                                                                              
  Automatically detects display connection/disconnection and reloads          
  aerospace and sketchybar configurations. Runs as a LaunchAgent that checks  
  every 3 seconds.                                                            
                                                                              
  Components:                                                                 
  • setup/monitor-watcher.sh - Detects display count changes using            
  system_profiler                                                             
  • setup/reload-display-config.sh - Reloads configs when changes detected    
  • templates/display-monitor.plist.tpl - LaunchAgent configuration           
                                                                              
  The system logs to ~/.config/logs/display-monitor.log and is automatically
  loaded by setup.sh if aerospace and sketchybar are installed.

  ### Spotlight Shortcuts LaunchAgent

  macOS re-enables Spotlight keyboard shortcuts on every restart. A
  LaunchAgent runs setup/disable-spotlight-shortcuts.sh at login to
  re-disable shortcuts 64, 65, and 160, preventing conflicts with Raycast.

  Components:
  • setup/disable-spotlight-shortcuts.sh - Disables shortcuts via defaults
  write and activateSettings
  • templates/spotlight-shortcuts.plist.tpl - LaunchAgent configuration

  The script waits 10 seconds for macOS to finish boot-time restoration,
  then applies the settings. Logs to ~/.config/logs/spotlight-shortcuts.log.

  ### Theme System

  Theme colors are centralized via `themes/theme.toml` (flavor + accent) and
  `themes/catppuccin-frappe/palette.toml` (hex values). The sync script
  (`setup/sync-theme.sh`) propagates colors to all tool configs:

  - **Generated files**: sketchybar/colors.sh, lsd/colors.yaml,
  atuin/themes/*.toml (full regeneration)
  - **Section markers**: starship.toml, fish/config.fish,
  fastfetch/config.jsonc, templates/git-config.tpl (content between
  `@theme:start`/`@theme:end` replaced)
  - **Flavor strings**: nvim, tmux, bat, atuin, kitty (flavor name updated)
  - **Upstream files**: kitty.conf, bat.tmTheme, glow, zed themes (manual
  download for flavor changes)

  To change themes: edit `themes/theme.toml`, run `setup/sync-theme.sh`.

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

  ### Fish Functions                                                          
                                                                              
  Custom functions in fish/functions/:                                        
                                                                              
  • refresh - Reload configured processes (aerospace, sketchybar, fish, tmux) 
  • secrets - Wrapper for secrets.sh                                          
  • gitdone - Switch to default branch and pull                               
  • clone - Clone work repos with archive detection                           
  • empty - Create empty commit with CI identity for triggering pipelines     
  • z - Zoxide wrapper for directory jumping                                  
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


