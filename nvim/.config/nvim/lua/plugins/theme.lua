-- ~/.config/nvim/lua/plugins/theme.lua
-- ~/.config/nvim/lua/plugins/theme.lua
return {
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      variant = "default", -- dark variant is the default
      italic_comments = true,
    },
    config = function(_, opts)
      require("cyberdream").setup(opts)
      vim.cmd.colorscheme("cyberdream")
    end,
  },
}