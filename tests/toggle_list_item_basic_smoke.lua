-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/toggle_list_item_basic_smoke.lua
-- Requires markdown treesitter parser available to the headless nvim.
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.bo.filetype = "markdown"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
api.toggle_list_item()

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "- hello", "expected '- hello', got " .. vim.inspect(lines[1]))

print("toggle_list_item_basic_smoke: OK")
