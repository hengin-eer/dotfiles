-- local js_formatters = { "biome-check" }
local js_formatters = { "oxfmt", "oxlint" }

return {
    "stevearc/conform.nvim",
    opts = {
        formatters_by_ft = {
            css = js_formatters,
            lua = { "stylua" },
            markdown = { "markdownlint" },
            json = js_formatters,
            javascript = js_formatters,
            javascriptreact = js_formatters,
            typescript = js_formatters,
            typescriptreact = js_formatters,
            vue = js_formatters,
            svelte = js_formatters,
            -- astro = { "prettier", "biome-check", "astro-language-server" },
            haskell = { "haskell-language-server" },
            cpp = { "clangd" },
            typst = { "tinymist" },
        },

        format_on_save = {
            timeout_ms = 2000,
            lsp_fallback = true,
            quiet = false,
        },
    },
}
