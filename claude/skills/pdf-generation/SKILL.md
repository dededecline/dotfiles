---
name: pdf-generation
description: Generate PDFs from Markdown on macOS using pandoc + BasicTeX (xelatex). Use when the user asks to convert a markdown file to PDF, "export to PDF", "make a PDF of this doc", render markdown as a printable/shareable document, or any markdown→PDF conversion. Handles Unicode characters (arrows ↔, →, em-dashes —), GitHub-style lists without preceding blank lines, and ensures bullets render correctly.
---

# PDF Generation Skill (Markdown → PDF)

Canonical workflow on this user's macOS setup for generating well-rendered PDFs from Markdown files, using `pandoc` with the `xelatex` engine from `basictex`.

## Prerequisites (already in the Brewfile)

Both tools are declared in `~/.config/.system/profiles/labels/all/Brewfile` and install on every machine:

```
brew "pandoc"                   # Universal document converter (md → PDF, etc.)
cask "basictex"                 # Minimal TeX Live distribution (pdflatex engine for pandoc)
```

Verify they're available:

```bash
which pandoc                         # /opt/homebrew/bin/pandoc
which xelatex                        # /Library/TeX/texbin/xelatex
```

If `xelatex` is not on `PATH`, source the macOS path helper once or prefix commands:

```bash
eval "$(/usr/libexec/path_helper)"
# or, per-command:
export PATH="/Library/TeX/texbin:$PATH"
```

If BasicTeX is missing, install it interactively (cask installer requires sudo/Touch ID):

```bash
brew install --cask basictex
```

## Canonical command

```bash
export PATH="/Library/TeX/texbin:$PATH"

pandoc INPUT.md \
  -f gfm \
  -s \
  --pdf-engine=xelatex \
  -V geometry:margin=0.8in \
  -V colorlinks=true \
  -V mainfont="Arial Unicode MS" \
  -V monofont="Menlo" \
  -H ~/.config/claude/skills/pdf-generation/header.tex \
  -o OUTPUT.pdf
```

Every flag is there for a reason — see the rationale below before dropping any of them.

## Rationale for each flag

| Flag | Why |
|---|---|
| `-f gfm` | Parses as GitHub Flavored Markdown. Without this, pandoc's default dialect treats a bulleted list that immediately follows a `**bold paragraph**` (no blank line between) as a paragraph continuation, rendering `- item` inline instead of as a list. GFM allows lists without preceding blank lines. |
| `-s` | Standalone — produces a full document (otherwise pandoc emits a bare fragment). |
| `--pdf-engine=xelatex` | Default `pdflatex` chokes on any non-Latin-1 Unicode character (e.g. arrows ↔, →, em-dash — if smart punctuation is off). `xelatex` handles Unicode natively. `lualatex` would also work but needs `lualatex-math.sty` which is **not in basictex**. |
| `-V mainfont="Arial Unicode MS"` | macOS system font at `/Library/Fonts/Arial Unicode.ttf`. Covers U+2022 (•), U+2192 (→), U+2194 (↔), and the full BMP. `Helvetica` / `Helvetica Neue` lack arrows. |
| `-V monofont="Menlo"` | Default macOS monospace. Covers Unicode arrows too (useful inside code blocks). |
| `-V geometry:margin=0.8in` | Comfortable page margins. |
| `-V colorlinks=true` | Clickable links rendered in color instead of boxed. |
| `-H header.tex` | Forces math-mode bullets (`$\bullet$`, `$\circ$`, `$\diamond$`) so list markers render regardless of main font glyph coverage. Also adds 4pt `\parskip`. See `header.tex` alongside this file. |

## Troubleshooting

**Symptom: `! LaTeX Error: Unicode character X (U+XXXX) not set up for use with LaTeX.`**
Cause: using `pdflatex`. Fix: `--pdf-engine=xelatex`.

**Symptom: `! LaTeX Error: File 'lualatex-math.sty' not found.`**
Cause: `--pdf-engine=lualatex` on basictex (missing package). Fix: use `xelatex`, or `sudo tlmgr install lualatex-math`.

**Symptom: `[WARNING] Missing character: There is no → (U+2192) in font ...`**
Cause: main font doesn't have the glyph. Fix: `-V mainfont="Arial Unicode MS"`.

**Symptom: bullet-list items run inline as part of the preceding paragraph in the PDF (`Problem 1 — Hardlinks. - qBittorrent ... - Sonarr ...`).**
Cause: default markdown parser requires a blank line before a list. Fix: add `-f gfm`, OR `-f markdown+lists_without_preceding_blankline`.

**Symptom: bullets render as empty squares or not at all.**
Cause: main font's `\textbullet` glyph is missing/broken. Fix: use the bundled `header.tex` which forces math-mode bullets.

**Symptom: `sudo: a terminal is required to read the password` when installing basictex.**
Cause: cask installer needs interactive sudo. Fix: run `brew install --cask basictex` directly in the user's terminal (Touch ID for sudo is configured, so this is near-instant).

**Symptom: `xelatex: command not found` after fresh basictex install.**
Cause: PATH not yet updated. Fix: `eval "$(/usr/libexec/path_helper)"` or open a new terminal.

## One-liner wrapper (optional)

If generating PDFs frequently, drop this into `~/.config/fish/functions/md2pdf.fish`:

```fish
function md2pdf --description 'Render a Markdown file to PDF via pandoc + xelatex'
    set -l input $argv[1]
    set -l output (string replace -r '\.md$' '.pdf' -- $input)
    if test -n "$argv[2]"
        set output $argv[2]
    end
    set -lx PATH /Library/TeX/texbin $PATH
    pandoc $input \
        -f gfm -s \
        --pdf-engine=xelatex \
        -V geometry:margin=0.8in \
        -V colorlinks=true \
        -V mainfont='Arial Unicode MS' \
        -V monofont='Menlo' \
        -H ~/.config/claude/skills/pdf-generation/header.tex \
        -o $output
end
```

Then: `md2pdf ~/Desktop/notes.md` → `~/Desktop/notes.pdf`.

## References

- Pandoc user guide: https://pandoc.org/MANUAL.html
- BasicTeX on Homebrew: https://formulae.brew.sh/cask/basictex
- Inspiration: https://gist.github.com/ilessing/7ff705de0f594510e463146762cef779
