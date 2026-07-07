local ensured_servers = {
    "lua_ls",
    "vim-language-server",
    "markdownlint",
    "prettier",
    "biome",
    "tsgo",
    "oxfmt",
    "oxlint",
    "html-lsp",
    "css-lsp",
    "tailwindcss-language-server",
    "astro-language-server",
    "haskell-language-server",
    "bashls",
    "shfmt",
    "clangd",
    "tinymist",
}
vim.lsp.enable(ensured_servers)

-- エラー表示のカスタマイズ
vim.diagnostic.config({
    -- virtual_text = {
    --     format = function(diagnostic)
    --         return string.format("%s (%s: %s)", diagnostic.message, diagnostic.source, diagnostic.code)
    --     end,
    -- },
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
    severity_sort = true,
})
