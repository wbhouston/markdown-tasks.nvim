local ts_utils = require("markdown-tasks.treesitter_utils")
local utils = require("markdown-tasks.utils")
local ListItemDecorator = require("markdown-tasks.decorators.list_item_decorator")

local M = {}

---@private
---@param cursor_row integer
function M.add_basic_list_item_marker(cursor_row)
	local first_node_on_cursor_row = vim.treesitter.get_node({ pos = { cursor_row, 0 } })
	local replace_start = 0
	if first_node_on_cursor_row ~= nil and first_node_on_cursor_row:type() == "block_continuation" then
		_, replace_start = first_node_on_cursor_row:end_()
	end

	vim.api.nvim_buf_set_text(0, cursor_row, replace_start, cursor_row, replace_start, { "- " })
	local cursor_eol = utils.get_eol(cursor_row)
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, cursor_eol })
end

function M.toggle_list_item()
	ts_utils.parse()

	local cursor_row, _ = utils.get_zero_indexed_cursor()
	local cursor_list_item = M.get_list_item(cursor_row)

	if cursor_list_item then
		if cursor_list_item.start_row == cursor_row then
			M.remove_list_item_markers_from_line(cursor_list_item)
		else
			M.add_list_item_markers_to_line(cursor_row)
		end
	else
		local next_line_cursor_item = M.get_list_item(cursor_row + 1)
		if next_line_cursor_item then
			M.add_list_item_markers_to_line(cursor_row)
		else
			M.add_basic_list_item_marker(cursor_row)
		end
	end
end

-- This is returning the list item on the previous line for blank lines.
-- If that changes, this search will need to be more rigorous.
---@private
---@param row integer
---@return markdown-tasks.decorators.ListItemDecorator?
function M.get_list_item(row)
	local eol = utils.get_eol(row)
	local node = vim.treesitter.get_node({ pos = { row, eol } })
	if node then
		local list_item = ts_utils.find_parent_node_by_type(node, "list_item")

		if list_item then
			return ListItemDecorator.new(list_item)
		end
	end
end

-- TODO: Consider new line behavior at the end and beginning of nested lists:
-- >- list item
-- >{case 1: add a line here}
-- >  - list item
-- > ...
-- >  - list item
-- >{case 2: add a line here}
-- >- list item
-- I feel like case 1 should always be the demoted list item because the
-- first list item already had a sublist.
-- I feel like case 2 should match the line it comes from.

---@private
---@param cursor_row integer
function M.add_list_item_markers_to_line(cursor_row)
	local first_node_on_cursor_row = vim.treesitter.get_node({ pos = { cursor_row, 0 } })
	local previous_row = cursor_row - 1
	local next_row = cursor_row + 1

	local previous_list_item = M.get_list_item(previous_row)
	local next_list_item = M.get_list_item(next_row)
	local previous_list, next_list
	local preferred_list_item = previous_list_item or next_list_item

	if previous_list_item and next_list_item then
		previous_list = previous_list_item:parent_list()
		next_list = next_list_item:parent_list()
		if previous_list and next_list then
			if previous_list:includes(next_list.node) then
				preferred_list_item = next_list_item
			end
		end
	end

	if not preferred_list_item then
		return
	end

	local replace_start = 0
	if first_node_on_cursor_row ~= nil and first_node_on_cursor_row:type() == "block_continuation" then
		_, replace_start = first_node_on_cursor_row:end_()
	end

	vim.api.nvim_buf_set_text(0, cursor_row, 0, cursor_row, replace_start, preferred_list_item:marker_text())

	local cursor_eol = utils.get_eol(cursor_row)
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, cursor_eol })
end

---@private
---@params list_item markdown-tasks.decorators.ListItemDecorator
function M.remove_list_item_markers_from_line(list_item)
	local marker = list_item:marker()
	local task_marker = list_item:task_marker()

	vim.api.nvim_buf_set_text(
		0,
		marker.start_row,
		marker.start_col,
		marker.start_row,
		(task_marker and task_marker.end_col) or marker.end_col,
		{}
	)
end

---@private
---@param row integer zero-based
---@return boolean
function M.is_blank_list_item(row)
	if row < 0 then
		return false
	end
	local lines = vim.api.nvim_buf_get_lines(0, row, row + 1, false)
	local line = lines[1]
	if not line then
		return false
	end
	return utils.is_blank_list_line(line)
end

---@private
function M.exit_blank_list_item()
	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1
	if previous_row < 0 then
		return
	end

	-- Clear the blank list item to an empty line (separator), then leave the
	-- cursor on the following empty line at column 0.
	vim.api.nvim_buf_set_lines(0, previous_row, previous_row + 1, false, { "" })
	vim.api.nvim_buf_set_lines(0, cursor_row, cursor_row + 1, false, { "" })
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, 0 })
end

function M.continue_list_item_on_new_line()
	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1
	if previous_row < 0 then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, previous_row, previous_row + 1, false)
	local previous_line = lines[1]
	if not previous_line or utils.is_empty_or_whitespace_line(previous_line) then
		return
	end

	ts_utils.parse()
	M.add_list_item_markers_to_line(cursor_row)
end

function M.on_new_line()
	ts_utils.parse()

	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1

	if previous_row >= 0 and M.is_blank_list_item(previous_row) then
		M.exit_blank_list_item()
		return
	end

	M.continue_list_item_on_new_line()
end

---@private
---@return integer
function M.list_indent_step()
	return vim.fn.shiftwidth()
end

---Column just past marker / task marker on the marker row.
---@private
---@param list_item markdown-tasks.decorators.ListItemDecorator
---@return integer? after_markers_col
---@return markdown-tasks.decorators.TSNodeDecorator? marker
function M.after_list_markers_col(list_item)
	local marker = list_item:marker()
	if not marker then
		return nil, nil
	end
	local after = marker.end_col
	local task = list_item:task_marker()
	if task then
		after = task.end_col
	end
	return after, marker
end

---Column of the list-marker glyph (`-`, `*`, `1.`, …).
---tree-sitter-markdown `list_marker_*` nodes include leading indent and the
---trailing space, so `marker.start_col` is not that glyph.
---@private
---@param line string
---@param marker markdown-tasks.decorators.TSNodeDecorator
---@return integer
function M.list_marker_glyph_col(line, marker)
	local col = marker.start_col
	local limit = marker.end_col
	if limit > #line then
		limit = #line
	end
	while col < limit do
		local ch = line:sub(col + 1, col + 1)
		if ch ~= " " and ch ~= "\t" then
			return col
		end
		col = col + 1
	end
	return marker.start_col
end

---@private
---@return boolean
function M.at_list_item_start()
	ts_utils.parse()
	local cursor_row, cursor_col = utils.get_zero_indexed_cursor()
	local list_item = M.get_list_item(cursor_row)
	if not list_item then
		return false
	end
	local after, marker = M.after_list_markers_col(list_item)
	if not marker or marker.start_row ~= cursor_row then
		return false
	end
	local line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false)[1] or ""
	local content_start = utils.list_item_content_start_col(line, after)
	return utils.is_cursor_at_list_item_start(cursor_col, content_start)
end

---@private
---@param delta integer positive = indent right
function M.shift_list_item_indent(delta)
	ts_utils.parse()
	local cursor_row, cursor_col = utils.get_zero_indexed_cursor()
	local list_item = M.get_list_item(cursor_row)
	if not list_item then
		return
	end
	local after, marker = M.after_list_markers_col(list_item)
	if not marker or marker.start_row ~= cursor_row then
		return
	end
	local line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false)[1] or ""
	local content_start = utils.list_item_content_start_col(line, after)
	local offset_from_content = cursor_col - content_start

	local col = M.list_marker_glyph_col(line, marker)
	if delta > 0 then
		vim.api.nvim_buf_set_text(0, cursor_row, col, cursor_row, col, { string.rep(" ", delta) })
	elseif delta < 0 then
		local remove = -delta
		vim.api.nvim_buf_set_text(0, cursor_row, col - remove, cursor_row, col, {})
	end

	local new_content_start = content_start + delta
	local new_col = new_content_start + offset_from_content
	if new_col < 0 then
		new_col = 0
	end
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, new_col })
end

---@return boolean handled
function M.indent_list_item()
	if not M.at_list_item_start() then
		return false
	end
	M.shift_list_item_indent(M.list_indent_step())
	return true
end

---@return boolean handled
function M.outdent_list_item()
	if not M.at_list_item_start() then
		return false
	end
	ts_utils.parse()
	local cursor_row = utils.get_zero_indexed_cursor()
	local list_item = M.get_list_item(cursor_row)
	if not list_item then
		return true
	end
	local _, marker = M.after_list_markers_col(list_item)
	if not marker then
		return true
	end
	local line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false)[1] or ""
	local step = M.list_indent_step()
	local available = utils.count_ascii_spaces_before(line, M.list_marker_glyph_col(line, marker))
	if available < step then
		return true
	end
	M.shift_list_item_indent(-step)
	return true
end

return M
