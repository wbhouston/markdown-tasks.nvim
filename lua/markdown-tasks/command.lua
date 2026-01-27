local ts_utils = require("markdown-tasks.treesitter_utils")
local utils = require("markdown-tasks.utils")

---@class markdown-tasks.command
local M = {}

local name = "MarkdownTasks"
local plugin = "markdown-tasks.nvim"

function M.init()
	vim.api.nvim_create_user_command(name, M.command, {
		desc = plugin .. "commands",
	})
end

---@private
---@param args vim.api.keyset.create_user_command.command_args
function M.command(args)
	local err = M.run(args.fargs)
	if err then
		vim.notify(("%s: %s"):format(plugin, err), vim.log.levels.ERROR)
	end
end

---@private
---@param fargs string[]
---@return string?
function M.run(fargs)
	local parser = vim.treesitter.get_parser(0)
	parser:parse()
	local cursor_line, _ = utils.get_zero_indexed_cursor()
	local cursor_eol = #vim.api.nvim_get_current_line()
	local list_item = ts_utils.find_parent_node_type("list_item", { pos = { cursor_line, cursor_eol } })
	if list_item == nil then
		return "no list item found"
	end

	local marker = ts_utils.find_child_node_type(list_item, {
		"list_marker_dot",
		"list_marker_minus",
		"list_marker_parenthesis",
		"list_marker_star",
	})

	if marker == nil then
		return "no list marker found"
	end

	local task_marker = ts_utils.find_child_node_type(list_item, {
		"task_list_marker_checked",
		"task_list_marker_unchecked",
	})

	local list_item_line = list_item:start()

	if cursor_line == list_item_line then
		local _, start_col, _, end_col = marker:range()
		if task_marker ~= nil then
			_, end_col = task_marker:end_()
			end_col = end_col + 1
		end

		vim.api.nvim_buf_set_text(0, cursor_line, start_col, cursor_line, end_col, {})
	else
		local start_line, _ = marker:start()
		local first_node_on_cursor_line = vim.treesitter.get_node({ pos = { cursor_line, 0 } })

		local start_col = 0
		if first_node_on_cursor_line ~= nil and first_node_on_cursor_line:type() == "block_continuation" then
			_, start_col = first_node_on_cursor_line:end_()
		end

		local end_col
		if task_marker == nil then
			_, end_col = marker:end_()
		else
			_, end_col = task_marker:end_()
			end_col = end_col + 1
		end

		local text = vim.api.nvim_buf_get_text(0, start_line, 0, start_line, end_col, {})
		vim.api.nvim_buf_set_text(0, cursor_line, 0, cursor_line, start_col, text)
	end
end

return M
