-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/indent_list_item_expr_schedule_smoke.lua
-- Ensures indent still works when mutation is deferred (expr-map textlock pattern).
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.bo.filetype = "markdown"
vim.bo.shiftwidth = 2
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- item" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })

assert(api.at_list_item_start() == true, "at start")
vim.schedule(function()
	assert(api.indent_list_item() == true, "indent handled")
end)

local ok = vim.wait(500, function()
	return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "  - item"
end)
assert(ok, "scheduled indent applied")

print("indent_list_item_expr_schedule_smoke: OK")
