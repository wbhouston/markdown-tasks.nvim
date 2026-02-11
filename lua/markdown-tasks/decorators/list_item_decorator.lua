local TSNodeDecorator = require("markdown-tasks.decorators.tsnode_decorator")

---@class markdown-tasks.decorators.ListItemDecorator: markdown-tasks.decorators.TSNodeDecorator
---@field decorated_node markdown-tasks.decorators.TSNodeDecorator
---@field cached_marker markdown-tasks.decorators.TSNodeDecorator?
---@field cached_task_marker markdown-tasks.decorators.TSNodeDecorator?
---@field cached_list markdown-tasks.decorators.TSNodeDecorator?
local ListItemDecorator = {}
ListItemDecorator.__index = function(table, key)
	return ListItemDecorator[key] or table.decorated_node[key]
end

---@param node TSNode
---@return markdown-tasks.decorators.ListItemDecorator
function ListItemDecorator.new(node)
	local o = { decorated_node = TSNodeDecorator.new(node) }
	o = setmetatable(o, ListItemDecorator)
	return o
end

---@return markdown-tasks.decorators.TSNodeDecorator?
function ListItemDecorator:marker()
	if self.cached_marker then
		return self.cached_marker
	else
		self.cached_marker = self.decorated_node:find_child_node_by_type({
			"list_marker_dot",
			"list_marker_minus",
			"list_marker_parenthesis",
			"list_marker_star",
		})

		return self.cached_marker
	end
end

---@return markdown-tasks.decorators.TSNodeDecorator?
function ListItemDecorator:task_marker()
	if self.cached_task_marker then
		return self.cached_task_marker
	else
		self.cached_task_marker = self.decorated_node:find_child_node_by_type({
			"task_list_marker_checked",
			"task_list_marker_unchecked",
		})

		return self.cached_task_marker
	end
end

---@return markdown-tasks.decorators.TSNodeDecorator?
function ListItemDecorator:parent_list()
	if self.cached_list then
		return self.cached_list
	else
		self.cached_list = self.decorated_node:find_parent_node_by_type("list")

		return self.cached_list
	end
end

---@return string[]
function ListItemDecorator:marker_text()
	if not self:marker() then
		return { "" }
	end

	local marker_row = self:marker().start_row
	local marker_end_col = self:marker().end_col

	if self:task_marker() ~= nil then
		marker_end_col = self:task_marker().end_col

		-- The the task marker doesn't extend to the beginning of the inline node.
		marker_end_col = marker_end_col + 1
	end

	return vim.api.nvim_buf_get_text(0, marker_row, 0, marker_row, marker_end_col, {})
end

return ListItemDecorator
