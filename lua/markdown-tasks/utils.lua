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

---0-based column of first non-whitespace at or after `after_markers_col`, or `#line` if none.
---@param line string
---@param after_markers_col integer
---@return integer
function M.list_item_content_start_col(line, after_markers_col)
	if after_markers_col < 0 then
		after_markers_col = 0
	end
	if after_markers_col > #line then
		return #line
	end
	local tail = line:sub(after_markers_col + 1)
	local non_ws = tail:find("%S")
	if not non_ws then
		return #line
	end
	return after_markers_col + non_ws - 1
end

---True when the insert cursor is still in the list-item prefix zone.
---When there is no content, `content_start_col` is `#line` and an insert-mode
---cursor may sit at EOL (`cursor_col == #line`); that still counts as at start.
---@param cursor_col integer
---@param content_start_col integer
---@param line_len integer
---@return boolean
function M.is_cursor_at_list_item_start(cursor_col, content_start_col, line_len)
	if cursor_col < content_start_col then
		return true
	end
	return content_start_col >= line_len and cursor_col <= line_len
end

---Count consecutive ASCII spaces (` `) immediately before 0-based `col`.
---@param line string
---@param col integer
---@return integer
function M.count_ascii_spaces_before(line, col)
	local n = 0
	local i = col
	while i > 0 do
		local ch = line:sub(i, i)
		if ch ~= " " then
			break
		end
		n = n + 1
		i = i - 1
	end
	return n
end

return M
