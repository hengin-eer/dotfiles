-- base options
vim.opt.number = true
vim.opt.virtualedit = "block"
vim.opt.wildmenu = true

-- cursor settings
vim.opt.cursorline = true
vim.opt.cursorcolumn = true

-- scroll offset as 5 lines
vim.opt.scrolloff = 5
-- move the cursor to the previous/next line across the first/last character
vim.opt.whichwrap = "b,s,h,l,<,>,[,],~"

-- tab&space settings
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4

vim.opt.bg = "light"
vim.opt.termguicolors = true

vim.opt.showmatch.matchtime = 1
vim.opt.showmatch = true
vim.opt.showcmd = true
vim.opt.helpheight = 999
vim.opt.visualbell = true
vim.opt.hlsearch = true

-- share clipboard with OS
vim.opt.clipboard:append("unnamedplus,unnamed")
