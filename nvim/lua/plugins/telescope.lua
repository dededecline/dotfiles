-- Telescope Fuzzy Finder

return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    -- Configure Telescope defaults
    require('telescope').setup({
      defaults = {},
    })

    -- Load project.nvim extension
    require('telescope').load_extension('projects')

    local builtin = require('telescope.builtin')

    -- Telescope keymaps - project.nvim automatically handles cwd
    vim.keymap.set('n', '<C-p>', builtin.find_files, { desc = 'Quick open (find files)' })
    vim.keymap.set('n', '<C-e>', builtin.oldfiles, { desc = 'Recently opened files' })
    vim.keymap.set('n', '<leader>f', builtin.live_grep, { desc = 'Search in files' })
    vim.keymap.set('n', '<C-f>', builtin.current_buffer_fuzzy_find, { desc = 'Find in file' })
    vim.keymap.set('n', '<leader>o', builtin.lsp_document_symbols, { desc = 'Go to symbol' })
    vim.keymap.set('n', '<leader>p', builtin.commands, { desc = 'Command palette' })
    vim.keymap.set('n', '<C-g>', builtin.git_files, { desc = 'Git files' })
    vim.keymap.set('n', '<F1>', builtin.help_tags, { desc = 'Help' })

    -- Project picker
    vim.keymap.set('n', '<leader>fp', '<cmd>Telescope projects<cr>', { desc = 'Find projects' })
  end,
}
