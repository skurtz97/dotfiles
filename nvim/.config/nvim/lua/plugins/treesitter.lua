-- ~/.config/nvim/lua/plugins/treesitter.lua
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { 
        "lua", "vim", "bash", "markdown", "c", "rust" 
      },
    },
  },
}