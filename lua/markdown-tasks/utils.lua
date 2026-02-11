local M = {}

---@return integer, integer
function M.get_zero_indexed_cursor()
	vim.api.nvim_win_get_cursor(0)
	local cursor_line, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
	return cursor_line - 1, cursor_col
end

---@param row integer
---@return integer
function M.get_eol(row)
	local line = unpack(vim.api.nvim_buf_get_lines(0, row, row + 1, false))
	if line then
		return #line
	else
		return 0
	end
end

return M
