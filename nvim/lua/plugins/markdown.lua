-- Markdown and Image Rendering

return {
  -- Markdown rendering
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {},
  },

  -- Image rendering in terminal (requires kitty or similar)
  {
    '3rd/image.nvim',
    build = false, -- disable automatic build, luarocks must be configured
    opts = {
      backend = 'kitty',
      processor = 'magick_cli', -- use CLI instead of luarock
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          only_render_image_at_cursor = false,
          floating_windows = false,
        },
      },
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = false,
      window_overlap_clear_ft_ignore = { 'cmp_menu', 'cmp_docs', '' },
    },
  },
}
