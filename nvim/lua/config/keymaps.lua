-- General Keymaps

-- Line wrapping navigation
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Quick quit
vim.keymap.set('n', '<leader>q', '<cmd>qa<cr>', { desc = 'Quit all' })
vim.keymap.set('n', '<leader>Q', '<cmd>qa!<cr>', { desc = 'Force quit all' })

-- Diagnostic keymaps
vim.keymap.set('n', '<S-F8>', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic' })
vim.keymap.set('n', '<F8>', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic' })
vim.keymap.set('n', '<leader>m', vim.diagnostic.setloclist, { desc = 'Open diagnostics list' })

-- Window splitting (VSCode-style)
vim.keymap.set('n', '<C-\\>', '<cmd>vsplit<cr>', { desc = 'Split editor right' })
vim.keymap.set('n', '<C-S-\\>', '<cmd>split<cr>', { desc = 'Split editor down' })
vim.keymap.set('n', '<C-w><C-\\>', '<cmd>split<cr>', { desc = 'Split editor down' })

-- Window navigation (VSCode-style with Ctrl+arrow)
vim.keymap.set('n', '<C-Left>', '<C-w>h', { desc = 'Focus left split' })
vim.keymap.set('n', '<C-Down>', '<C-w>j', { desc = 'Focus below split' })
vim.keymap.set('n', '<C-Up>', '<C-w>k', { desc = 'Focus above split' })
vim.keymap.set('n', '<C-Right>', '<C-w>l', { desc = 'Focus right split' })

-- Window management
vim.keymap.set('n', '<C-w>=', '<C-w>=', { desc = 'Equal split sizes' })
vim.keymap.set('n', '<C-w>m', '<C-w>_<C-w>|', { desc = 'Maximize current split' })

-- Tab navigation (VSCode-style workspaces)
vim.keymap.set('n', '<C-Tab>', '<cmd>tabnext<cr>', { desc = 'Next tab' })
vim.keymap.set('n', '<C-S-Tab>', '<cmd>tabprevious<cr>', { desc = 'Previous tab' })
vim.keymap.set('n', '<C-w>t', '<cmd>tabnew<cr>', { desc = 'New tab' })
vim.keymap.set('n', '<C-w>q', '<cmd>tabclose<cr>', { desc = 'Close tab' })
for i = 1, 9 do
  vim.keymap.set('n', '<M-' .. i .. '>', '<cmd>tabnext ' .. i .. '<cr>', { desc = 'Go to tab ' .. i })
end
