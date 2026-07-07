return {
    "stevearc/oil.nvim",
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
        default_file_explorer = true,

        -- float window settings
        float = {
            padding = 2,
            max_width = 80,
            max_height = 20,
            border = "rounded",
            win_options = {
                -- 背景を少し透過させる
                winblend = 10,
            },
        },

        -- view settings
        view_options = {
            show_hidden = true,
            is_always_hidden = function(name, bufnr)
                -- 特定のディレクトリを隠しファイル表示をオンにしても表示させない
                return name == ".git"
            end,
        },
    },
    -- Optional dependencies
    -- dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
    -- Lazy loading is not recommended because it is very tricky to make it work correctly in all situations.
    lazy = false,
}
