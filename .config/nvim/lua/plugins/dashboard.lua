local function read_header(filepath)
        local lines = {}
        local f = io.open(filepath, "r")

        if not f then
                return { "Dashboard", "Header file not found!" }
        end

        for line in f:lines() do
                table.insert(lines, line)
        end

        f:close()
        return lines
end

local config_dir = vim.fn.stdpath('config')
local header_file = config_dir .. '/AA-dashboard.txt'

return {
  'nvimdev/dashboard-nvim',
  event = 'VimEnter',
  config = function()
    require('dashboard').setup {
            config = {
                    header = read_header(header_file)
            }
    }
  end,
  dependencies = { {'nvim-tree/nvim-web-devicons'}}
}
