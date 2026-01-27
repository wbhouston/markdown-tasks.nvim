local ts = vim.treesitter

local group = vim.api.nvim_create_augroup("render-tasks.nvim", {})

local M = {}

function M.find_parent_node_type(type, opts)
	local node = ts.get_node(opts)

	while node ~= nil and node:type() ~= type do
		node = node:parent()
	end

	return node
end

function M.find_child_node_type(node, types)
	local stack = {}

	while node ~= nil and not vim.tbl_contains(types, node:type()) do
		for index, child in ipairs(node:named_children()) do
			table.insert(stack, child)
		end
		node = table.remove(stack)
	end

	return node
end

return M
