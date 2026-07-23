-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: 
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.colorcolumn = { "71", "80", "100", "120" }

vim.api.nvim_create_autocmd("ColorScheme", {
  callback = function()
    vim.api.nvim_set_hl(0, "ColorColumn", { bg = "#1f2126" })
    vim.api.nvim_set_hl(0, "CursorLine", { bg = "#1c1e24" })
  end,
})