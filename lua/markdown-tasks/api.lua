local ts_utils = require("markdown-tasks.treesitter_utils")
local utils = require("markdown-tasks.utils")

local M = {}

---@param copy_marker_before boolean
function M.toggle_list_item(copy_marker_before)
	ts_utils.parse()

	local cursor_line, _ = utils.get_zero_indexed_cursor()
	local cursor_eol = #vim.api.nvim_get_current_line()
  local search_line = cursor_line - 1

  if not copy_marker_before then
    search_line = cursor_line + 1
  end

	-- This is returning the list item on the previous line for blank lines.
	-- If that changes, this search will need to be more rigorous.
	local list_item = ts_utils.find_parent_node_by_type("list_item", { pos = { search_line, cursor_eol } })
	local cursor_list_item = ts_utils.find_parent_node_by_type("list_item", { pos = { search_line, cursor_eol } })

	if list_item == nil then
		return
	end

	-- BUG: need to only search immediate children of the list item
	local marker = ts_utils.find_child_node_by_type(list_item, {
		"list_marker_dot",
		"list_marker_minus",
		"list_marker_parenthesis",
		"list_marker_star",
	})

	if marker == nil then
		return "no list marker found"
	end

	local task_marker = ts_utils.find_child_node_by_type(list_item, {
		"task_list_marker_checked",
		"task_list_marker_unchecked",
	})

	local list_item_line, _ = list_item:start()

	if cursor_line == list_item_line then
		M.remove_list_item_markers_from_line(cursor_line, marker, task_marker)
	else
		M.add_list_item_markers_to_line(cursor_line, marker, task_marker)
	end
end

-- BUG: when adding to the line before, the following line's indentation is used
---@private
---@param cursor_line integer
---@param marker TSNode
---@param task_marker TSNode?
---@return string?
function M.add_list_item_markers_to_line(cursor_line, marker, task_marker)
	local first_node_on_cursor_line = vim.treesitter.get_node({ pos = { cursor_line, 0 } })
	local marker_line, _, _, marker_end_col = marker:range()
	local replace_start = 0

	if first_node_on_cursor_line ~= nil and first_node_on_cursor_line:type() == "block_continuation" then
		_, replace_start = first_node_on_cursor_line:end_()
	end

	if task_marker ~= nil then
		_, marker_end_col = task_marker:end_()

		-- The the task marker doesn't extend to the beginning of the inline node.
		marker_end_col = marker_end_col + 1
	end

	local text = vim.api.nvim_buf_get_text(0, marker_line, 0, marker_line, marker_end_col, {})
	vim.api.nvim_buf_set_text(0, cursor_line, 0, cursor_line, replace_start, text)

	local cursor_eol = #vim.api.nvim_get_current_line()
	vim.api.nvim_win_set_cursor(0, { cursor_line + 1, cursor_eol })
end

---@private
---@param cursor_line integer
---@param marker TSNode
---@param task_marker TSNode?
function M.remove_list_item_markers_from_line(cursor_line, marker, task_marker)
	local _, start_col, _, end_col = marker:range()

	if task_marker ~= nil then
		_, end_col = task_marker:end_()

		-- The the task marker doesn't extend to the beginning of the inline node.
		end_col = end_col + 1
	end

	vim.api.nvim_buf_set_text(0, cursor_line, start_col, cursor_line, end_col, {})
end

return M
