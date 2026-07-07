require("options")
require("config.lazy")
require("keymaps")
require("lsp")

-- set colorscheme
vim.cmd([[color catppuccin-macchiato]])

vim.api.nvim_create_user_command("InitLua", function()
    vim.cmd.edit(vim.fn.stdpath("config") .. "/init.lua")
end, { desc = "Open init.lua" })
