-- ~/.config/nvim/lua/plugins/theme.lua
return {
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        background = { dark = "wave", light = "lotus" },
        theme = "wave",
      })
      vim.cmd.colorscheme("kanagawa")
    end,
  },
}