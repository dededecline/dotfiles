-- Catppuccin Theme

return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup({
      flavour = 'frappe',
      integrations = {
        bufferline = true,
      },
    })
    vim.cmd.colorscheme 'catppuccin'
  end,
}
