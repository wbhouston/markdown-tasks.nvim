--@class trouble: trouble.api
local M = {}
local command = require('markdown-tasks.command')

--@param opts? trouble.Config
function M.setup(opts)
  vim.notify('initialized markdown-tasks')
  command.init()
end

return setmetatable(M, {
  __index = function(_, k)
    --return require("trouble.api")[k]
  end,
})
