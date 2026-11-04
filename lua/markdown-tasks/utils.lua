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

---True when `line` is empty or only whitespace.
---@param line string
---@return boolean
function M.is_empty_or_whitespace_line(line)
	return line:match("^%s*$") ~= nil
end

---True when `line` is a list/task marker with no content after the prefix.
---Leading whitespace and blockquote `>` markers are ignored as content.
---@param line string
---@return boolean
function M.is_blank_list_line(line)
	if not line or line == "" then
		return false
	end

	local s = line:match("^%s*(.*)$")
	while true do
		local tail = s:match("^>%s*(.*)$")
		if not tail then
			break
		end
		s = tail
	end

	-- Lua patterns have no `|` alternation, `?`, or `*` on groups; match marker variants explicitly.
	if s:match("^[-*+]%s*$") then
		return true
	end
	if s:match("^[-*+]%s+%[[ xX]%]%s*$") then
		return true
	end
	if s:match("^%d+[.)]%s*$") then
		return true
	end
	return s:match("^%d+[.)]%s+%[[ xX]%]%s*$") ~= nil
end

return M
