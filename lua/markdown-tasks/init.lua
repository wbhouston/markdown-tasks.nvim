--@class trouble: trouble.api
local M = {}
local command = require("markdown-tasks.command")
local group = vim.api.nvim_create_augroup("markdown-tasks.nvim", {})

M.attached_bufs = {}

--@param opts? trouble.Config
function M.setup(opts)
	vim.notify("initialized markdown-tasks")
	command.init()
	vim.api.nvim_create_autocmd("Filetype", {
		group = group,
		pattern = vim.treesitter.language.get_filetypes("markdown"),
		callback = function(args)
			M.on_attach(args.buf)
		end,
	})
end

function M.on_attach(buf)
	if vim.tbl_contains(M.attached_bufs, buf) then
		return
	end

	table.insert(M.attached_bufs, buf)

	vim.api.nvim_set_keymap("i", "<cr>", "<cr><cmd>MarkdownTasks on_new_line<cr>", {})
	vim.api.nvim_set_keymap("n", "o", "o<cmd>MarkdownTasks on_new_line<cr>", {})
	vim.api.nvim_set_keymap("n", "O", "O<cmd>MarkdownTasks continue_list_item_on_new_line<cr>", {})
	vim.api.nvim_set_keymap("n", "<leader>tl", "<cmd>MarkdownTasks toggle_list_item<cr>", {})

	vim.keymap.set("i", "<Tab>", function()
		if require("markdown-tasks.api").indent_list_item() then
			return ""
		end
		return "<Tab>"
	end, { expr = true, buffer = buf })

	vim.keymap.set("i", "<S-Tab>", function()
		if require("markdown-tasks.api").outdent_list_item() then
			return ""
		end
		return "<S-Tab>"
	end, { expr = true, buffer = buf })
end

return setmetatable(M, {
	__index = function(_, k)
		--return require("trouble.api")[k]
	end,
})
