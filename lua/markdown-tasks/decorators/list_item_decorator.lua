local TSNodeDecorator = require("markdown-tasks.decorators.tsnode_decorator")

---@class markdown-tasks.decorators.ListItemDecorator
---@field decorated_node markdown-tasks.decorators.TSNodeDecorator
---@field cached_marker markdown-tasks.decorators.TSNodeDecorator?
---@field cached_task_marker markdown-tasks.decorators.TSNodeDecorator?
local ListItemDecorator = {}
ListItemDecorator.__index = ListItemDecorator

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

return ListItemDecorator
