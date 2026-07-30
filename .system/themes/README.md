# Themes

This directory contains the centralized theme configuration.

**Current Theme: Catppuccin Frappe with Lavender accent (#babbf1)**

## Structure

```
.system/themes/
├── theme.toml                     # Single source of truth (flavor + accent)
└── catppuccin-frappe/
    ├── palette.toml               # Color hex values
    ├── kitty.conf                 # Upstream kitty theme
    ├── bat.tmTheme                # Upstream bat theme
    └── wallpapers/                # Desktop wallpapers
```

## How It Works

`.system/themes/theme.toml` declares the flavor and accent color. Running `.system/setup/sync-theme.sh` reads this file plus the palette and updates all downstream tool configs automatically.

### What gets synced

| Category | Files | Method |
|----------|-------|--------|
| Generated | `sketchybar/colors.sh`, `lsd/colors.yaml`, `atuin/themes/*.toml` | Entire file regenerated |
| Section | `starship/starship.toml`, `fish/config.fish`, `fastfetch/config.jsonc`, `.system/templates/git-config.tpl` | Content between `@theme:start`/`@theme:end` markers replaced |
| Flavor string | `nvim`, `tmux`, `bat`, `atuin/config.toml`, `kitty` | Flavor name updated via sed |
| Upstream | `kitty.conf`, `bat.tmTheme`, `glow/*.json`, `zed/themes/*.json` | Not auto-synced (manual download for flavor changes) |

For `fastfetch/config.jsonc`, `sync_fastfetch` also rewrites the seven
`logo.color` stripe values and the separator via sed, on top of the marker
section. The module `keyColor` values are not rewritten and go stale on a flavor
change (reported as `unknown color pattern` warnings). See the Fastfetch Logos
section in the root `CLAUDE.md` for the `$1`…`$7` striping contract.

## Changing the Theme

1. Edit `.system/themes/theme.toml` (set flavor and accent)
2. If switching flavors, download upstream theme files for the new flavor into `.system/themes/catppuccin-<flavor>/`
3. Run `.system/setup/sync-theme.sh`
4. Run `bat cache --build` if bat theme changed
5. Restart terminals and reload configs (`refresh`)

## Adding a New Tool

1. Determine which category the tool falls into (generated, section marker, flavor string, or upstream)
2. Add a sync function to `.system/setup/sync-theme.sh`
3. For section replacement: add `# @theme:start` / `# @theme:end` markers to the config file
4. For generated files: add an auto-generated header comment
