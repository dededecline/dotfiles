-- Neovim Configuration
-- Converted from nix-config: https://github.com/dededecline/nix-config

-- Disable netrw BEFORE anything else (must run before lazy.nvim loads)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Set leader keys
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Core options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.clipboard = 'unnamedplus'
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.termguicolors = true
vim.opt.autoread = true
