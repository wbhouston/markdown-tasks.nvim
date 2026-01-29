local ts_utils = require("markdown-tasks.treesitter_utils")

---@class markdown-tasks.decorators.TSNodeDecorator
---@field node TSNode
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer
local TSNodeDecorator = {}
TSNodeDecorator.__index = TSNodeDecorator

---@param node TSNode
---@return markdown-tasks.decorators.TSNodeDecorator
function TSNodeDecorator.new(node)
	local o = { node = node }
	o = setmetatable(o, TSNodeDecorator)
	o.start_row, o.start_col, o.end_row, o.end_col = node:range(false)
	return o
end

---@param types table
---@return markdown-tasks.decorators.TSNodeDecorator?
function TSNodeDecorator:find_child_node_by_type(types)
	local child = ts_utils.find_child_node_by_type(self.node, types)
	if child then
		return TSNodeDecorator.new(child)
	end
end

return TSNodeDecorator
