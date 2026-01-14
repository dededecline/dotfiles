# Themes

This directory contains consolidated theme configurations.

**Accent Color: Lavender (#babbf1)**

All tools are configured to use lavender as the primary accent for cursor, selection, active tabs, and highlights.

## Structure

```
themes/
└── catppuccin-frappe/
    ├── palette.toml    # Central color reference (source of truth)
    ├── kitty.conf      # Kitty terminal theme (lavender accent)
    └── bat.tmTheme     # Bat syntax highlighting theme
```

## Usage

Each tool references the theme from this central location:

| Tool     | Method                                          |
|----------|------------------------------------------------|
| kitty    | `include ../themes/catppuccin-frappe/kitty.conf` |
| bat      | Symlinked from `bat/themes/`                   |
| starship | Palette inline (TOML can't import)             |
| lsd      | Colors inline (YAML can't import)              |
| tmux     | Uses catppuccin/tmux TPM plugin                |

## Updating Colors

1. Edit `palette.toml` with new values
2. For tools with inline colors (starship, lsd), manually sync the values
3. Run `bat cache --build` if bat theme changes
