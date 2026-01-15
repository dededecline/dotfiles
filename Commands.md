# Commands Cheatsheet

> **Hyper** = `Ctrl+Alt+Cmd`

## Aerospace (Window Manager)

| Action | Shortcut |
|--------|----------|
| Focus up/left/down/right | `Hyper` + `I/J/K/L` |
| Move window up/left/down/right | `Hyper+Shift` + `I/J/K/L` |
| Workspace 1-7 | `Hyper` + `Q/W/E/R/T/Y/U` |
| Move to workspace 1-7 | `Hyper+Shift` + `Q/W/E/R/T/Y/U` |
| Toggle fullscreen | `Hyper+Shift+F` |
| Toggle float/tile | `Hyper+F` |
| Toggle tiles layout | `Hyper+/` |
| Toggle accordion layout | `Hyper+,` |
| Resize window | `Hyper+Shift` + `-/=` |
| Previous workspace | `Hyper+Tab` |
| Move workspace to monitor | `Hyper+Shift+Tab` |
| Service mode | `Hyper+Shift+;` |

**Service Mode:**
| Action | Key |
|--------|-----|
| Reload config & exit | `Esc` |
| Flatten workspace | `R` |
| Toggle float | `F` |
| Close other windows | `Backspace` |
| Join with direction | `I/J/K/L` |

## Atuin (Shell History)

| Action | Shortcut |
|--------|----------|
| Search history | `Ctrl+R` |
| Navigate results | `Ctrl+N/P` or arrows |
| Accept selection | `Enter` |
| Filter current host (up arrow) | `Up` |

## Fish Shell

| Action | Shortcut |
|--------|----------|
| Autocomplete | `Tab` |
| Accept autosuggestion | `Right` or `Ctrl+F` |
| Clear line | `Ctrl+U` |
| Cancel command | `Ctrl+C` |
| History search | `Ctrl+R` (via Atuin) |

## Kitty (Terminal)

| Action | Shortcut |
|--------|----------|
| Search scrollback | `Cmd+F` |
| Go to tab 1-9 | `Cmd+1-9` |
| New tab | `Cmd+T` |
| Close tab | `Cmd+W` |
| Next/prev tab | `Cmd+Shift+]/[` |
| Scroll up/down | `Cmd+Up/Down` |

## Neovim

**General:**
| Action | Shortcut |
|--------|----------|
| Leader key | `Space` |
| Toggle file explorer | `Ctrl+B` |
| Quit all | `Space+Q` |
| Force quit all | `Space+Shift+Q` |

**Telescope (Fuzzy Finder):**
| Action | Shortcut |
|--------|----------|
| Quick open (files) | `Ctrl+P` |
| Recent files | `Ctrl+E` |
| Search in files | `Space+F` |
| Find in buffer | `Ctrl+F` |
| Go to symbol | `Space+O` |
| Command palette | `Space+P` |
| Git files | `Ctrl+G` |
| Help | `F1` |

**Diagnostics:**
| Action | Shortcut |
|--------|----------|
| Next diagnostic | `F8` |
| Previous diagnostic | `Shift+F8` |
| Diagnostics list | `Space+M` |

**Completion:**
| Action | Shortcut |
|--------|----------|
| Trigger completion | `Ctrl+Space` |
| Next/prev item | `Tab/Shift+Tab` or `Ctrl+N/P` |
| Confirm selection | `Enter` |

**Window Splitting (VSCode-style):**
| Action | Shortcut |
|--------|----------|
| Split editor right | `Ctrl+\` |
| Split editor down | `Ctrl+Shift+\` or `Ctrl+W Ctrl+\` |
| Focus left/down/up/right split | `Ctrl+Arrow` |
| Close current split | `Ctrl+W C` |
| Close all other splits | `Ctrl+W O` |
| Equal split sizes | `Ctrl+W =` |
| Maximize current split | `Ctrl+W M` |

**Window Splitting (Vim-native):**
| Action | Shortcut |
|--------|----------|
| Split right (vertical) | `Ctrl+W V` or `:vsplit` |
| Split down (horizontal) | `Ctrl+W S` or `:split` |
| Focus left/down/up/right | `Ctrl+W H/J/K/L` |
| Move split left/down/up/right | `Ctrl+W Shift+H/J/K/L` |
| Increase/decrease width | `Ctrl+W >/<` |
| Increase/decrease height | `Ctrl+W +/-` |
| Rotate splits | `Ctrl+W R` |


## Tmux

Prefix: `Ctrl+B`

| Action | Shortcut |
|--------|----------|
| New window | `Prefix + C` |
| Next/prev window | `Prefix + N/P` |
| Split vertical | `Prefix + %` |
| Split horizontal | `Prefix + "` |
| Switch pane | `Prefix + arrow` |
| Close pane | `Prefix + X` |
| Detach session | `Prefix + D` |
| List sessions | `Prefix + S` |
| Rename window | `Prefix + ,` |

## Raycast

| Action | Shortcut |
|--------|----------|
| Open Raycast | `Cmd+Space` |
| Clipboard history | `Cmd+Shift+V` |
| Window management | `Ctrl+Opt+arrow` |
| Emoji picker | `Cmd+.` |
| Calculator | type math in Raycast |
| File search | `Cmd+Space` then filename |

## Dotfiles Management

| Command | Description |
|---------|-------------|
| `refresh` | Reload all configured processes (fish, aerospace, sketchybar, tmux) |
| `refresh fish` | Reload Fish shell config only |
| `refresh aerospace` | Reload Aerospace window manager config only |
| `refresh sketchybar` | Reload Sketchybar status bar config only |
| `refresh tmux` | Reload Tmux config only (if in tmux session) |
| `secrets` | Inject secrets from 1Password |
| `secrets check` | Check which secrets are configured |
| `dotfiles` | Navigate to ~/.config directory |
