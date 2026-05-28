# basedpyright-lsp

Python language server (basedpyright) for Claude Code, providing static type
checking and code intelligence. This is the local-marketplace counterpart to the
official `pyright-lsp` plugin, swapped to use `basedpyright` so Claude Code and
Zed share a single type checker.

## Supported extensions

`.py`, `.pyi`

## Requirements

The `basedpyright` Homebrew formula (provides `basedpyright-langserver`), which
is declared in `.system/profiles/labels/all/Brewfile`.

## More information

- [basedpyright](https://docs.basedpyright.com/)
- LSP server config lives inline in `../../.claude-plugin/marketplace.json`.
