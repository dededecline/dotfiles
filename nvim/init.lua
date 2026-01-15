-- Neovim Configuration
-- Converted from nix-config: https://github.com/dededecline/nix-config

-- Load core configuration
require('config.options')
require('config.keymaps')
require('config.autocmds')

-- Bootstrap and setup lazy.nvim
require('config.lazy')
