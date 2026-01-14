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

-- Auto-reload files changed outside of Neovim
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
  command = 'checktime',
})

-- Line wrapping navigation
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Quick quit
vim.keymap.set('n', '<leader>q', '<cmd>qa<cr>', { desc = 'Quit all' })
vim.keymap.set('n', '<leader>Q', '<cmd>qa!<cr>', { desc = 'Force quit all' })

-- Diagnostic keymaps (VSCode-style)
vim.keymap.set('n', '<S-F8>', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
vim.keymap.set('n', '<F8>', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })
vim.keymap.set('n', '<C-S-m>', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

-- Bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugin specifications
require('lazy').setup({
  -- Catppuccin theme
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    config = function()
      require('catppuccin').setup({ flavour = 'frappe' })
      vim.cmd.colorscheme 'catppuccin'
    end,
  },

  -- Git integration
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '-' },
        changedelete = { text = '~' },
      },
    },
  },

  -- Status line
  {
    'nvim-lualine/lualine.nvim',
    opts = {
      options = {
        theme = 'catppuccin',
        component_separators = '|',
        section_separators = '',
      },
    },
  },

  -- Comment toggling
  { 'numToStr/Comment.nvim', opts = {} },

  -- Indent guides
  { 'lukas-reineke/indent-blankline.nvim', main = 'ibl', opts = {} },

  -- Icons
  { 'nvim-tree/nvim-web-devicons', opts = { default = true } },

  -- File explorer (nvim-tree)
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<C-b>', '<cmd>NvimTreeToggle<cr>', desc = 'Toggle file explorer' },
    },
    init = function()
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = function()
          local arg = vim.fn.argv(0)
          if arg ~= '' and vim.fn.isdirectory(arg) == 1 then
            require('nvim-tree.api').tree.open({ path = arg })
          end
        end,
      })
    end,
    opts = {
      actions = {
        open_file = {
          quit_on_open = false,
          window_picker = { enable = true },
        },
      },
      view = {
        width = 30,
      },
      filters = {
        dotfiles = false,
        git_ignored = false,
      },
      update_focused_file = {
        enable = true,
        update_root = false,
      },
      renderer = {
        highlight_git = true,
        icons = {
          show = {
            git = true,
            folder = true,
            file = true,
          },
        },
      },
    },
  },

  -- Telescope fuzzy finder
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      local builtin = require('telescope.builtin')
      -- VSCode-style keymaps
      vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = 'Quick open (find files)' })
      vim.keymap.set('n', '<C-e>', builtin.oldfiles, { desc = 'Recently opened files' })
      vim.keymap.set('n', '<C-S-f>', builtin.live_grep, { desc = 'Search in files' })
      vim.keymap.set('n', '<C-f>', builtin.current_buffer_fuzzy_find, { desc = 'Find in file' })
      vim.keymap.set('n', '<C-S-o>', builtin.lsp_document_symbols, { desc = 'Go to symbol' })
      vim.keymap.set('n', '<C-S-p>', builtin.commands, { desc = 'Command palette' })
      vim.keymap.set('n', '<C-g>', builtin.git_files, { desc = 'Git files' })
      vim.keymap.set('n', '<F1>', builtin.help_tags, { desc = 'Help' })
    end,
  },

  -- LSP configuration
  {
    'williamboman/mason.nvim',
    opts = {},
  },
  {
    'williamboman/mason-lspconfig.nvim',
    dependencies = { 'williamboman/mason.nvim' },
    opts = {
      ensure_installed = { 'lua_ls' },
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      'williamboman/mason.nvim',
      'williamboman/mason-lspconfig.nvim',
    },
    config = function()
      -- Use vim.lsp.config for Neovim 0.11+
      vim.lsp.config('lua_ls', {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })
      vim.lsp.enable('lua_ls')
    end,
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'L3MON4D3/LuaSnip',
      'saadparwaiz1/cmp_luasnip',
    },
    config = function()
      local cmp = require('cmp')
      local luasnip = require('luasnip')

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-n>'] = cmp.mapping.select_next_item(),
          ['<C-p>'] = cmp.mapping.select_prev_item(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = {
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
          { name = 'buffer' },
          { name = 'path' },
        },
      })
    end,
  },

  -- Markdown rendering
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  { 'folke/snacks.nvim', opts = {} },

  {
    'coder/claudecode.nvim',
    dependencies = { 'folke/snacks.nvim' },
    opts = {
      terminal = {
        split_side = 'right',
        split_width_percentage = 0.4,
      },
    },
    keys = {
      { '<C-;>', '<cmd>ClaudeCode<cr>', desc = 'Toggle Claude' },
      { '<C-S-;>', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
      { '<C-S-a>', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
      { '<C-Enter>', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept diff' },
      { '<C-Backspace>', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny diff' },
    },
  },
})
