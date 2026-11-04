-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/indent_list_item_smoke.lua
-- Requires markdown treesitter parser.
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.bo.filetype = "markdown"
vim.bo.shiftwidth = 2

local function reset(lines, row, col)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.api.nvim_win_set_cursor(0, { row, col })
end

-- Indent at start
reset({ "- item" }, 1, 0)
assert(api.indent_list_item() == true, "indent handled")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "  - item", "indented line")
local r, c = unpack(vim.api.nvim_win_get_cursor(0))
assert(r == 1 and c == 2, "cursor moved with indent, got " .. r .. "," .. c)

-- Not at start → fall through
reset({ "- item" }, 1, 4) -- on 't' of item (approx; adjust if needed)
local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
assert(api.indent_list_item() == false, "mid-content fallthrough")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == before, "unchanged")

-- Outdent
reset({ "  - item" }, 1, 2)
assert(api.outdent_list_item() == true, "outdent handled")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "- item", "outdented line")

-- Insufficient outdent → handled no-op
reset({ "- item" }, 1, 0)
assert(api.outdent_list_item() == true, "outdent at zero handled")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "- item", "unchanged at zero")

-- Children not moved
reset({ "- parent", "  - child" }, 1, 0)
assert(api.indent_list_item() == true, "indent parent")
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "  - parent", "parent indented")
assert(lines[2] == "  - child", "child unchanged")

print("indent_list_item_smoke: OK")
