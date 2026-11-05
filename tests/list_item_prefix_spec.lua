-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/list_item_prefix_spec.lua
local utils = require("markdown-tasks.utils")

local function assert_eq(actual, expected, msg)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", msg, tostring(expected), tostring(actual)), 2)
	end
end

-- "- item" — marker ends at col 1; after_markers = 1 → content at 'i' (col 2)
assert_eq(utils.list_item_content_start_col("- item", 1), 2, "simple content start")
assert_eq(utils.list_item_content_start_col("- [ ] buy", 5), 6, "after task checkbox space")
assert_eq(utils.list_item_content_start_col("- [ ]   buy", 5), 8, "whitespace after task")
assert_eq(utils.list_item_content_start_col("- ", 1), 2, "no content → EOL")
assert_eq(utils.list_item_content_start_col("- [ ]   ", 5), 8, "blank item trailing ws → EOL")

-- With content (e.g. "- item", content at col 2, line len 6): strict before content
assert_eq(utils.is_cursor_at_list_item_start(0, 2, 6), true, "before content")
assert_eq(utils.is_cursor_at_list_item_start(1, 2, 6), true, "in prefix")
assert_eq(utils.is_cursor_at_list_item_start(2, 2, 6), false, "on first content char")
assert_eq(utils.is_cursor_at_list_item_start(3, 2, 6), false, "past content start")

-- Blank item "- " (len 2): content_start is EOL; insert cursor at EOL must count as start
assert_eq(utils.is_cursor_at_list_item_start(2, 2, 2), true, "EOL on blank item")
assert_eq(utils.is_cursor_at_list_item_start(1, 2, 2), true, "in blank trailing space")
assert_eq(utils.is_cursor_at_list_item_start(0, 2, 2), true, "on marker of blank item")

assert_eq(utils.count_ascii_spaces_before("  - item", 2), 2, "two spaces before marker")
assert_eq(utils.count_ascii_spaces_before("- item", 0), 0, "bol")
assert_eq(utils.count_ascii_spaces_before("\t  - item", 3), 2, "tabs do not count; only spaces before col")
assert_eq(utils.count_ascii_spaces_before(">   - item", 4), 3, "spaces after quote")

print("list_item_prefix_spec: OK")
