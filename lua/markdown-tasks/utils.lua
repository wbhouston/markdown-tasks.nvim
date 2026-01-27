local M = {}

function M.get_zero_indexed_cursor()
	local cursor_line, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	return cursor_line - 1, cursor_col
end

return M
