-- Project Management

return {
  'ahmedkhalf/project.nvim',
  dependencies = { 'nvim-telescope/telescope.nvim' },
  config = function()
    require('project_nvim').setup({
      -- Detection methods (in priority order)
      detection_methods = { 'pattern', 'lsp' },

      -- Patterns to detect project root
      patterns = { '.git', '_darcs', '.hg', '.bzr', '.svn', 'Makefile', 'package.json', 'Cargo.toml' },

      -- Tab-local scope to preserve multi-workspace behavior
      scope_chdir = 'tab',

      -- Don't show messages when changing directory
      silent_chdir = true,

      -- Show hidden files in telescope picker
      show_hidden = false,

      -- Path where project history is stored
      datapath = vim.fn.stdpath('data'),
    })
  end,
}
