local ts_utils = require("markdown-tasks.treesitter_utils")
local utils = require("markdown-tasks.utils")
local ListItemDecorator = require("markdown-tasks.decorators.list_item_decorator")

local M = {}

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

return M
