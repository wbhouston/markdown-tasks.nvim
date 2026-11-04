-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/exit_blank_list_item_smoke.lua
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- foo", "- ", "" })
vim.api.nvim_win_set_cursor(0, { 3, 0 })
api.exit_blank_list_item()

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local row, col = unpack(vim.api.nvim_win_get_cursor(0))

assert(#lines == 3, "expected 3 lines, got " .. #lines)
assert(lines[1] == "- foo", "line 1")
assert(lines[2] == "", "separator blank")
assert(lines[3] == "", "cursor line blank")
assert(row == 3 and col == 0, "cursor at col 0 on line 3")

print("exit_blank_list_item_smoke: OK")
