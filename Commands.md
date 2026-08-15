# Commands Cheatsheet

> **Hyper** = `Ctrl+Alt+Cmd`

## Aerospace (Window Manager)

| Action                         | Shortcut                  |
| ------------------------------ | ------------------------- |
| Focus up/left/down/right       | `Hyper` + `I/J/K/L`       |
| Move window up/left/down/right | `Hyper+Shift` + `I/J/K/L` |
| Workspace 1-9                  | `Hyper` + `1-9`           |
| Move to workspace 1-9          | `Hyper+Shift` + `1-9`     |
| Toggle fullscreen              | `Hyper+Shift+F`           |
| Toggle float/tile              | `Hyper+F`                 |
| Toggle tiles layout            | `Hyper+/`                 |
| Toggle accordion layout        | `Hyper+,`                 |
| Resize window                  | `Hyper+Shift` + `-/=`     |
| Previous workspace             | `Hyper+Tab`               |
| Move workspace to monitor      | `Hyper+Shift+Tab`         |
| Service mode                   | `Hyper+Shift+;`           |

**Service Mode:**

| Action               | Key         |
| -------------------- | ----------- |
| Reload config & exit | `Esc`       |
| Flatten workspace    | `R`         |
| Toggle float         | `F`         |
| Close other windows  | `Backspace` |
| Join with direction  | `I/J/K/L`   |

## Atuin (Shell History)

| Action                         | Shortcut             |
| ------------------------------ | -------------------- |
| Search history                 | `Ctrl+R`             |
| Navigate results               | `Ctrl+N/P` or arrows |
| Accept selection               | `Enter`              |
| Filter current host (up arrow) | `Up`                 |

## Fish Shell

| Action                  | Shortcut             |
| ----------------------- | -------------------- |
| Autocomplete            | `Tab`                |
| Accept autosuggestion   | `Right` or `Ctrl+F`  |
| Clear line              | `Ctrl+U`             |
| Cancel command          | `Ctrl+C`             |
| History search          | `Ctrl+R` (via Atuin) |
| Paste file path (fzf)   | `Ctrl+T`             |
| cd into directory (fzf) | `Alt+C`              |

## Kitty (Terminal)

| Action            | Shortcut         |
| ----------------- | ---------------- |
| Search scrollback | `Cmd+F`          |
| Go to tab 1-9     | `Cmd+1-9`        |
| New tab           | `Cmd+T`          |
| Close tab         | `Cmd+W`          |
| Next/prev tab     | `Cmd+Shift+]/[`  |
| Scroll up/down    | `Cmd+Up/Down`    |
| Word back/forward | `Alt+Left/Right` |
| Line start/end    | `Cmd+Left/Right` |

## Neovim

**General:**

| Action               | Shortcut        |
| -------------------- | --------------- |
| Leader key           | `Space`         |
| Toggle file explorer | `Ctrl+B`        |
| Quit all             | `Space+Q`       |
| Force quit all       | `Space+Shift+Q` |

**Telescope (Fuzzy Finder):**

| Action             | Shortcut   |
| ------------------ | ---------- |
| Quick open (files) | `Ctrl+P`   |
| Recent files       | `Ctrl+E`   |
| Search in files    | `Space+F`  |
| Find in buffer     | `Ctrl+F`   |
| Go to symbol       | `Space+O`  |
| Command palette    | `Space+P`  |
| Git files          | `Ctrl+G`   |
| Find projects      | `Space+FP` |
| Help               | `F1`       |

**Claude AI:**

| Action                   | Shortcut           |
| ------------------------ | ------------------ |
| Toggle Claude panel      | `Ctrl+;`           |
| Focus Claude panel       | `Space+;`          |
| Send selection to Claude | `Space+A` (visual) |
| Accept diff              | `Ctrl+Enter`       |
| Deny diff                | `Ctrl+Backspace`   |

**Diagnostics:**

| Action              | Shortcut   |
| ------------------- | ---------- |
| Next diagnostic     | `F8`       |
| Previous diagnostic | `Shift+F8` |
| Diagnostics list    | `Space+M`  |

**Completion:**

| Action             | Shortcut                      |
| ------------------ | ----------------------------- |
| Trigger completion | `Ctrl+Space`                  |
| Next/prev item     | `Tab/Shift+Tab` or `Ctrl+N/P` |
| Confirm selection  | `Enter`                       |

**Tabs:**

| Action        | Shortcut                      |
| ------------- | ----------------------------- |
| Next/prev tab | `Ctrl+Tab` / `Ctrl+Shift+Tab` |
| New tab       | `Ctrl+W T`                    |
| Close tab     | `Ctrl+W Q`                    |
| Go to tab 1-9 | `Alt+1-9`                     |

**Window Splitting (VSCode-style):**

| Action                         | Shortcut                          |
| ------------------------------ | --------------------------------- |
| Split editor right             | `Ctrl+\`                          |
| Split editor down              | `Ctrl+Shift+\` or `Ctrl+W Ctrl+\` |
| Focus left/down/up/right split | `Ctrl+Arrow`                      |
| Close current split            | `Ctrl+W C`                        |
| Close all other splits         | `Ctrl+W O`                        |
| Equal split sizes              | `Ctrl+W =`                        |
| Maximize current split         | `Ctrl+W M`                        |

**Window Splitting (Vim-native):**

| Action                        | Shortcut                |
| ----------------------------- | ----------------------- |
| Split right (vertical)        | `Ctrl+W V` or `:vsplit` |
| Split down (horizontal)       | `Ctrl+W S` or `:split`  |
| Focus left/down/up/right      | `Ctrl+W H/J/K/L`        |
| Move split left/down/up/right | `Ctrl+W Shift+H/J/K/L`  |
| Increase/decrease width       | `Ctrl+W >/<`            |
| Increase/decrease height      | `Ctrl+W +/-`            |
| Rotate splits                 | `Ctrl+W R`              |

## Tmux

Prefix: `Ctrl+B`

| Action           | Shortcut         |
| ---------------- | ---------------- |
| New window       | `Prefix + C`     |
| Next/prev window | `Prefix + N/P`   |
| Split vertical   | `Prefix + %`     |
| Split horizontal | `Prefix + "`     |
| Switch pane      | `Prefix + arrow` |
| Close pane       | `Prefix + X`     |
| Detach session   | `Prefix + D`     |
| List sessions    | `Prefix + S`     |
| Rename window    | `Prefix + ,`     |

## Raycast

| Action            | Shortcut                  |
| ----------------- | ------------------------- |
| Open Raycast      | `Cmd+Space`               |
| Clipboard history | `Cmd+Shift+V`             |
| Window management | `Ctrl+Opt+arrow`          |
| Emoji picker      | `Cmd+.`                   |
| Calculator        | type math in Raycast      |
| File search       | `Cmd+Space` then filename |

## CLI Replacements

**Tool Replacements:**

| Alias    | Replacement    | Notes                           |
| -------- | -------------- | ------------------------------- |
| `ls`     | `lsd`          | Modern ls with icons            |
| `cat`    | `bat` / `glow` | bat for code, glow for markdown |
| `find`   | `fd`           | Faster, friendlier find         |
| `diff`   | `delta`        | Better diff viewer              |
| `du`     | `dust`         | Better disk usage               |
| `ping`   | `gping`        | Graphical ping                  |
| `top`    | `btop`         | Better process monitor          |
| `fetch`  | `fastfetch`    | System info display             |
| `vim`    | `nvim`         | Neovim                          |
| `pip`    | `pip3`         | Python 3 pip                    |
| `python` | `python3`      | Python 3                        |

**Listing Shortcuts:**

| Alias | Command  |
| ----- | -------- |
| `l`   | `ls -l`  |
| `la`  | `ls -a`  |
| `ll`  | `ls -la` |

**Git Shortcuts:**

| Alias  | Command         |
| ------ | --------------- |
| `gs`   | `git status`    |
| `gb`   | `git branch`    |
| `gc`   | `git checkout`  |
| `gd`   | `git diff`      |
| `ga`   | `git add`       |
| `gp`   | `git push`      |
| `gl`   | `git pull`      |
| `gst`  | `git stash`     |
| `gpop` | `git stash pop` |

**Other Aliases:**

| Alias        | Command                                  |
| ------------ | ---------------------------------------- |
| `search`     | `grep -rnw . -e` (recursive word search) |
| `tofulint`   | `tofu fmt && tofu validate`              |
| `fishconfig` | Edit fish config in nvim                 |
| `kctx`       | `kubectl config current-context`         |
| `dotfiles`   | `cd ~/.config`                           |

## Fish Functions

| Command                 | Description                                                                                                            |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `setup`                 | Run setup.sh from anywhere (passes all args through)                                                                   |
| `refresh`               | Reload all configured processes (fish, aerospace, sketchybar, tmux)                                                    |
| `refresh <target>`      | Reload specific target: `fish`, `aerospace`, `sketchybar`, `tmux`                                                      |
| `secrets`               | Inject secrets from 1Password                                                                                          |
| `secrets check`         | Check which secrets are configured                                                                                     |
| `cat <file>`            | Smart cat: glow for markdown, bat for everything else                                                                  |
| `sketchybar reload`     | Reload sketchybar config                                                                                               |
| `sketchybar restart`    | Full restart via launchctl                                                                                             |
| `sketchybar stop/start` | Stop or start sketchybar                                                                                               |
| `gitdone`               | Switch to default branch and pull                                                                                      |
| `clone <repo>...`       | Clone one or more work repos: checks each name exists, warns on archived, offers to open in zed if only one was cloned |
| `clone -s <repo>...`    | Same, non-interactive: clones archived repos without asking, does not open zed                                         |
| `empty`                 | Empty commit to trigger CI pipelines                                                                                   |
