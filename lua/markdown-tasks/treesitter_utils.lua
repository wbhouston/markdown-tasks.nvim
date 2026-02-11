local ts = vim.treesitter

local M = {}

---@param node TSNode
---@param types table
---@return TSNode?
function M.find_child_node_by_type(node, types)
	for _, child in ipairs(node:named_children()) do
		if vim.tbl_contains(types, child:type()) then
			return child
		end
	end
end

---@params node TSNode
---@param type string
---@return TSNode?
function M.find_parent_node_by_type(node, type)
	while node ~= nil and node:type() ~= type do
		node = node:parent()
	end

	return node
end

function M.parse()
	vim.treesitter.get_parser(0):parse()
end

---@param opts vim.treesitter.get_node.Opts
---@return TSNode?
function M.get_node(opts)
	return vim.treesitter.get_node(opts)
end

return M
