-- ============================================================================
-- Neovim Configuration (init.lua)
-- ============================================================================

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- Core Plugin Setup
-- ============================================================================
require("lazy").setup({
  -- LSP development
  { "folke/lazydev.nvim", ft = "lua", opts = {} },
  -- Kanagawa Theme
  {
    "rebelot/kanagawa.nvim",
    name = "kanagawa",
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        compile = false,
        background = { dark = "wave", light = "lotus" },
        theme = "wave", -- wave, dragon, or lotus
        colors = { theme = { all = { ui = { bg_gutter = "none" } } } },
      })
      -- Apply the theme
      vim.cmd.colorscheme("kanagawa")
    end
  },
  -- Tree-sitter: High-performance syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        -- Languages to install (add more as you need them)
        ensure_installed = { "lua", "vim", "bash", "markdown", "c", "rust" },

        -- Enable high-performance syntax highlighting
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },

        -- Enable indentation based on the tree
        indent = {
          enable = true,
        },
      })
    end,
  }
})
