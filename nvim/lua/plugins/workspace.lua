-- Multi-directory workspace support (like VSCode's `code dir1 dir2 dir3`)
-- Opens each directory in its own tab with tab-local working directory

local function setup_multi_directory_workspace()
  local args = vim.fn.argv()
  if #args <= 1 then
    return false -- Let normal single-directory handling take over
  end

  -- Check if all args are directories
  local dirs = {}
  for _, arg in ipairs(args) do
    local path = vim.fn.fnamemodify(arg, ':p')
    if vim.fn.isdirectory(path) == 1 then
      table.insert(dirs, path)
    end
  end

  if #dirs < 2 then
    return false -- Not enough directories for multi-workspace mode
  end

  -- Clear the argument list to prevent default buffer creation
  vim.cmd('argdelete *')

  -- Create a tab for each directory
  for i, dir in ipairs(dirs) do
    if i == 1 then
      -- Use the first tab (already exists)
      vim.cmd('tcd ' .. vim.fn.fnameescape(dir))
    else
      -- Create new tab for subsequent directories
      vim.cmd('tabnew')
      vim.cmd('tcd ' .. vim.fn.fnameescape(dir))
    end
  end

  -- Go back to first tab
  vim.cmd('tabfirst')
  return true
end

vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if setup_multi_directory_workspace() then
      -- Open nvim-tree for first workspace after short delay
      vim.defer_fn(function()
        require('nvim-tree.api').tree.open()
      end, 10)
    end
  end,
  once = true,
})

-- This file doesn't return a plugin spec, it just sets up the workspace system
return {}
