-- UI Components: Status line and Tabline

return {
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

  -- Tabline for workspaces (shows directory name per tab)
  {
    'akinsho/bufferline.nvim',
    version = '*',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'catppuccin/nvim' },
    opts = {
      options = {
        mode = 'tabs', -- Show tabs, not buffers
        separator_style = 'slant',
        show_buffer_close_icons = false,
        show_close_icon = false,
        always_show_bufferline = false, -- Only show when multiple tabs
        name_formatter = function(tab)
          -- Show the tab-local working directory name
          local tabnr = tab.tabnr
          local cwd = vim.fn.getcwd(-1, tabnr)
          return vim.fn.fnamemodify(cwd, ':t')
        end,
      },
    },
  },
}
