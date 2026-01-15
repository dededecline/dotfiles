-- File Explorer (nvim-tree)

return {
  'nvim-tree/nvim-tree.lua',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  keys = {
    { '<C-b>', '<cmd>NvimTreeToggle<cr>', desc = 'Toggle file explorer' },
  },
  init = function()
    -- Single directory: open nvim-tree on startup
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        -- Skip if multi-workspace mode handled it (argc > 1)
        if vim.fn.argc() > 1 then
          return
        end
        local arg = vim.fn.argv(0)
        if arg ~= '' and vim.fn.isdirectory(arg) == 1 then
          require('nvim-tree.api').tree.open({ path = arg })
        end
      end,
    })
    -- Update nvim-tree root when switching tabs (for multi-workspace support)
    -- Works with project.nvim's tab-local scope for immediate visual feedback
    vim.api.nvim_create_autocmd('TabEnter', {
      callback = function()
        local api = require('nvim-tree.api')
        local cwd = vim.fn.getcwd()
        -- Change tree root to current tab's directory if tree is open
        if api.tree.is_visible() then
          api.tree.change_root(cwd)
        end
      end,
    })
  end,
  opts = {
    sync_root_with_cwd = true,
    respect_buf_cwd = true,
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
      update_root = true,
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
}
