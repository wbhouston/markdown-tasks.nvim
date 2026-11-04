-- Run: nvim --headless -u NONE -l tests/is_blank_list_line_spec.lua
local utils = require("markdown-tasks.utils")

local function assert_eq(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)), 2)
	end
end

local blank = {
	"-",
	"- ",
	"  - [ ]",
	"> - [x] ",
	"1. ",
	"* ",
	"+",
	"  2) ",
	"> > - [ ]",
}

local not_blank = {
	"- hello",
	"- [ ] buy milk",
	"plain text",
	"",
	"1. item",
	"> not a list",
}

for _, line in ipairs(blank) do
	assert_eq(utils.is_blank_list_line(line), true, "blank: " .. vim.inspect(line))
end

for _, line in ipairs(not_blank) do
	assert_eq(utils.is_blank_list_line(line), false, "not blank: " .. vim.inspect(line))
end

print("is_blank_list_line_spec: OK")
