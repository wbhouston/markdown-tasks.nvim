-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/continue_list_item_on_new_line_smoke.lua
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- foo", "", "" })
vim.api.nvim_win_set_cursor(0, { 3, 0 })
api.continue_list_item_on_new_line()

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "- foo", "line 1 preserved")
assert(lines[2] == "", "separator preserved")
assert(lines[3] == "", "cursor line stays plain empty, got " .. vim.inspect(lines[3]))

print("continue_list_item_on_new_line_smoke: OK")
