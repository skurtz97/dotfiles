-- ============================================================================
-- Neovim Configuration (init.lua)
-- ============================================================================

-- Bootstrap lazy.nvim (Modern plugin manager)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Safely resolve Neovim's filesystem API without linter confusion
local fs = vim.uv or vim.loop

if not fs.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
