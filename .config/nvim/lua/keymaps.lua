vim.g.mapleader = " "
-- vim keymap config
vim.keymap.set("i", "jj", "<esc>", { desc = "Escape from insert mode by using `jj`" })
-- Oil's shortcut
-- NOTE: 公式設定に準拠させてプレフィックスを`-`にした
vim.keymap.set("n", "-", function()
    require("oil").open_float()
end, { desc = "Open Oil in floating window" })

-- Bufferline's utils
vim.keymap.set("n", "<Left>", "<CMD>bp<CR>")
vim.keymap.set("n", "<C-h>", "<CMD>bp<CR>")
vim.keymap.set("n", "<Right>", "<CMD>bn<CR>")
vim.keymap.set("n", "<C-l>", "<CMD>bn<CR>")
-- vim.keymap.set('n', '<leader>wl', '<CMD>BufferLineCloseRight<CR>')
-- vim.keymap.set('n', '<leader>wh', '<CMD>BufferLineCloseLeft<CR>')
vim.keymap.set("n", "<leader>bo", "<CMD>BufferLineCloseOthers<CR>") -- selecting Buffer Only

-- telescope's utils
local function telescope_builtin(name)
    return function()
        require("telescope.builtin")[name]()
    end
end

vim.keymap.set("n", "<Leader>ff", telescope_builtin("find_files"), { desc = "Find Files" })
vim.keymap.set("n", "<Leader>fg", telescope_builtin("live_grep"), { desc = "Live Grep" })
vim.keymap.set("n", "<leader>fb", telescope_builtin("buffers"), { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", telescope_builtin("help_tags"), { desc = "Telescope help tags" })

-- Spectre's utils
vim.keymap.set("n", "<leader>sr", function()
    require("spectre").open()
end, { desc = "Open Spectre" })
vim.keymap.set("n", "<leader>sw", function()
    require("spectre").open_visual({ select_word = true })
end, { desc = "Search current word with Spectre" })
vim.keymap.set("v", "<leader>sw", function()
    require("spectre").open_visual()
end, { desc = "Search selection with Spectre" })
vim.keymap.set("n", "<leader>sp", function()
    require("spectre").open_file_search({ select_word = true })
end, { desc = "Search current file with Spectre" })

-- LSP configs
-- NOTE: LSPがバッファにアタッチされた時のみキーマップを展開する
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", {}),
    callback = function(ev)
        -- バッファローカルなキーマップにするためのオプション
        local opts = { buffer = ev.buf, silent = true }
        local keymap = vim.keymap.set

        -- Go xxx
        keymap("n", "gd", vim.lsp.buf.definition, opts) -- Go Definition (定義へ移動)
        keymap("n", "gD", vim.lsp.buf.declaration, opts) -- Go Declaration (宣言へ移動)
        keymap("n", "gr", vim.lsp.buf.references, opts) -- Go References (参照一覧を表示)
        keymap("n", "gi", vim.lsp.buf.implementation, opts) -- Go Implementation (実装へ移動)
        keymap("n", "gy", vim.lsp.buf.type_definition, opts) -- Go tYpe definition (型定義へ移動)

        -- Show Information
        keymap("n", "K", vim.lsp.buf.hover, opts) -- カーソル下のドキュメント表示
        keymap("n", "gl", vim.diagnostic.open_float, opts) -- 行の診断(エラー)メッセージをフロート表示 (Go Line)

        -- Actions
        keymap("n", "<leader>rn", vim.lsp.buf.rename, opts) -- ReName (変数名などの一括置換)
        keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts) -- Code Action (クイックフィックスやリファクタ提案)
        keymap("n", "<leader>fm", function() -- ForMat (コードフォーマット)
            vim.lsp.buf.format({ async = true })
        end, opts)

        -- Jump diagnostic
        keymap("n", "[d", vim.diagnostic.goto_prev, opts) -- 前の診断(エラー/警告)へ
        keymap("n", "]d", vim.diagnostic.goto_next, opts) -- 次の診断(エラー/警告)へ
    end,
})
