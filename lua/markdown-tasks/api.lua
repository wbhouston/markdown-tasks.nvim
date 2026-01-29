local ts_utils = require("markdown-tasks.treesitter_utils")
local utils = require("markdown-tasks.utils")
local TSNodeDecorator = require("markdown-tasks.decorators.tsnode_decorator")

local M = {}

---@param copy_marker_before boolean
function M.toggle_list_item(copy_marker_before)
	ts_utils.parse()

	local cursor_row, _ = utils.get_zero_indexed_cursor()
	local cursor_list_item = M.get_list_item(cursor_row)

	if cursor_list_item then
		if cursor_list_item.start_row == cursor_row then
			M.remove_list_item_markers_from_line(cursor_list_item)
		else
			M.add_list_item_markers_to_line(copy_marker_before, cursor_row, cursor_list_item)
		end
	end
	--
	--  if not copy_marker_before then
	--    search_line = cursor_line + 1
	--  end
	--
	-- -- This is returning the list item on the previous line for blank lines.
	-- -- If that changes, this search will need to be more rigorous.
	-- local list_item = ts_utils.find_parent_node_by_type("list_item", { pos = { search_line, cursor_eol } })
	-- local cursor_list_item = ts_utils.find_parent_node_by_type("list_item", { pos = { cursor_line, cursor_eol } })
	--
	-- if list_item == nil then
	-- 	return
	-- end
	--
	-- -- BUG: need to only search immediate children of the list item
	-- local marker = ts_utils.find_child_node_by_type(list_item, {
	-- 	"list_marker_dot",
	-- 	"list_marker_minus",
	-- 	"list_marker_parenthesis",
	-- 	"list_marker_star",
	-- })
	--
	-- if marker == nil then
	-- 	return "no list marker found"
	-- end
	--
	-- local task_marker = ts_utils.find_child_node_by_type(list_item, {
	-- 	"task_list_marker_checked",
	-- 	"task_list_marker_unchecked",
	-- })
	--
	--  local cursor_list_item_line = 0
	--
	--  if cursor_list_item then
	--    cursor_list_item_line, _ = list_item:start()
	--  end
	--
	--  print(cursor_list_item_line)
	-- if cursor_line == cursor_list_item_line then
	-- 	M.remove_list_item_markers_from_line(cursor_line, marker, task_marker)
	-- else
	-- 	M.add_list_item_markers_to_line(cursor_line, marker, task_marker)
	-- end
end

---@private
---@param row integer
---@return markdown-tasks.decorators.TSNodeDecorator?
function M.get_list_item(row)
	local eol = #unpack(vim.api.nvim_buf_get_lines(0, row, row + 1, false))
	local list_item = ts_utils.find_parent_node_by_type("list_item", { pos = { row, eol } })
	if list_item then
		return TSNodeDecorator.new(list_item)
	end
end

-- BUG: when adding to the line before, the following line's indentation is used
---@private
---@param copy_marker_before boolean
---@param cursor_row integer
---@params cursor_list_item markdown-tasks.decorators.TSNodeDecorator
---@return string?
function M.add_list_item_markers_to_line(copy_marker_before, cursor_row, cursor_list_item)
	local first_node_on_cursor_row = vim.treesitter.get_node({ pos = { cursor_row, 0 } })
	local search_row = copy_marker_before and cursor_row - 1 or cursor_row + 1

	-- This is returning the list item on the previous line for blank lines.
	-- If that changes, this search will need to be more rigorous.
	local search_list_item = M.get_list_item(search_row)

	if search_list_item == nil then
		return
	end

	-- BUG: need to only search immediate children of the list item
	local marker = search_list_item:find_child_node_by_type({
		"list_marker_dot",
		"list_marker_minus",
		"list_marker_parenthesis",
		"list_marker_star",
	})

	if marker == nil then
		return "no list marker found"
	end

	local task_marker = search_list_item:find_child_node_by_type({
		"task_list_marker_checked",
		"task_list_marker_unchecked",
	})

	local marker_row = marker.start_row
	local marker_end_col = marker.end_col
	local replace_start = 0

	if first_node_on_cursor_row ~= nil and first_node_on_cursor_row:type() == "block_continuation" then
		_, replace_start = first_node_on_cursor_row:end_()
	end

	if task_marker ~= nil then
		marker_end_col = task_marker.end_col

		-- The the task marker doesn't extend to the beginning of the inline node.
		marker_end_col = marker_end_col + 1
	end

	local text = vim.api.nvim_buf_get_text(0, marker_row, 0, marker_row, marker_end_col, {})
	vim.api.nvim_buf_set_text(0, cursor_row, 0, cursor_row, replace_start, text)

	local cursor_eol = #unpack(vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false))
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, cursor_eol })
end

---@private
---@params list_item markdown-tasks.decorators.TSNodeDecorator
function M.remove_list_item_markers_from_line(list_item)
	local marker = list_item:find_child_node_by_type({
		"list_marker_dot",
		"list_marker_minus",
		"list_marker_parenthesis",
		"list_marker_star",
	})

	local task_marker = list_item:find_child_node_by_type({
		"task_list_marker_checked",
		"task_list_marker_unchecked",
	})

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
