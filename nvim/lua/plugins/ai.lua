-- AI Integration

return {
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
      { '<leader>;', '<cmd>ClaudeCodeFocus<cr>', desc = 'Focus Claude' },
      { '<leader>a', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = 'Send to Claude' },
      { '<C-Enter>', '<cmd>ClaudeCodeDiffAccept<cr>', desc = 'Accept diff' },
      { '<C-Backspace>', '<cmd>ClaudeCodeDiffDeny<cr>', desc = 'Deny diff' },
    },
  },
}
