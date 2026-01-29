local api = require('markdown-tasks.api')

---@class markdown-tasks.command
local M = {}

local name = "MarkdownTasks"
local plugin = "markdown-tasks.nvim"

function M.init()
	vim.api.nvim_create_user_command(name, M.command, {
		desc = plugin .. "commands",
		nargs = '*',
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
	if #fargs > 2 then
		return "invalid number of arguments:" .. #fargs
	end

	local method = fargs[1] or "toggle_list_item"
	local command = api[method]

	if not command then
		return "invalid method name: " .. method
	end

	if #fargs == 2 then
		local command_args = fargs[2]

		if command_args == 'true' then
			command(true)
		else
			command(false)
		end
	else
		command(true)
	end
end

return M
