-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/is_empty_or_whitespace_line_spec.lua
local utils = require("markdown-tasks.utils")

local function assert_eq(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)), 2)
	end
end

local empty = { "", " ", "   ", "\t", " \t " }
local not_empty = { "-", "- ", "a", " - ", "hello" }

for _, line in ipairs(empty) do
	assert_eq(utils.is_empty_or_whitespace_line(line), true, "empty: " .. vim.inspect(line))
end

for _, line in ipairs(not_empty) do
	assert_eq(utils.is_empty_or_whitespace_line(line), false, "not empty: " .. vim.inspect(line))
end

print("is_empty_or_whitespace_line_spec: OK")
