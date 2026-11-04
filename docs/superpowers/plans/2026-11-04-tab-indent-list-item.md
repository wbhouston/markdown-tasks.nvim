# Tab / Shift-Tab List Indent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In insert mode, `<Tab>` / `<S-Tab>` indent or outdent the current list item by `shiftwidth()` when the cursor is in the list-item prefix zone; otherwise fall through to normal Tab / Shift-Tab.

**Architecture:** Pure string helpers in `utils` decide content-start columns and whether enough ASCII spaces exist before the marker. `api.indent_list_item` / `api.outdent_list_item` use treesitter + `ListItemDecorator` for marker bounds, mutate the current line only, and return whether the key was handled. Buffer-local insert `<expr>` maps in `on_attach` return `""` when handled or the original key for fallthrough.

**Tech Stack:** Neovim Lua plugin, vim.treesitter markdown parser, existing `ListItemDecorator` / `MarkdownTasks` dispatch, headless `nvim -l` specs and smokes.

## Global Constraints

- Indent/outdent only the **current line** (not nested children).
- Step size is `vim.fn.shiftwidth()` spaces (always ASCII spaces, never tab chars).
- At start = marker row == cursor row and `cursor_col < content_start_col` (prefix includes marker, optional task checkbox, trailing whitespace before content).
- Insufficient outdent → no-op but **handled** (`true`); not at start → fall through (`false`).
- Cursor keeps offset relative to first content character (or end of prefix if no content).
- No blockquote special case; insert/delete at `marker.start_col`.
- New keymaps are buffer-local `<expr>` maps; do not change existing `<CR>` / `o` / `O` maps.

## File Structure

| File | Responsibility |
|------|----------------|
| `lua/markdown-tasks/utils.lua` | Pure helpers: content-start col, spaces-before-col, at-start predicate |
| `lua/markdown-tasks/api.lua` | `indent_list_item` / `outdent_list_item` + private helpers |
| `lua/markdown-tasks/init.lua` | Buffer-local `i_<Tab>` / `i_<S-Tab>` expr maps |
| `tests/list_item_prefix_spec.lua` | Headless unit tests for pure helpers |
| `tests/indent_list_item_smoke.lua` | Headless API smoke (needs markdown treesitter) |
| `lua/markdown-tasks/command.lua` | No change (already dispatches `api[method]`) |

---

### Task 1: Pure prefix / spaces helpers

**Files:**
- Modify: `lua/markdown-tasks/utils.lua`
- Create: `tests/list_item_prefix_spec.lua`

**Interfaces:**
- Consumes: none
- Produces:
  - `utils.list_item_content_start_col(line: string, after_markers_col: integer): integer` — 0-based column of first non-whitespace at/after `after_markers_col`, or `#line` if none
  - `utils.is_cursor_at_list_item_start(cursor_col: integer, content_start_col: integer): boolean` — `cursor_col < content_start_col`
  - `utils.count_ascii_spaces_before(line: string, col: integer): integer` — consecutive ` ` chars immediately before 0-based `col`

- [ ] **Step 1: Write the failing spec**

Create `tests/list_item_prefix_spec.lua`:

```lua
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

assert_eq(utils.is_cursor_at_list_item_start(0, 2), true, "before content")
assert_eq(utils.is_cursor_at_list_item_start(1, 2), true, "in prefix")
assert_eq(utils.is_cursor_at_list_item_start(2, 2), false, "on first content char")
assert_eq(utils.is_cursor_at_list_item_start(3, 2), false, "past content start")

assert_eq(utils.count_ascii_spaces_before("  - item", 2), 2, "two spaces before marker")
assert_eq(utils.count_ascii_spaces_before("- item", 0), 0, "bol")
assert_eq(utils.count_ascii_spaces_before("\t  - item", 3), 2, "tabs do not count; only spaces before col")
assert_eq(utils.count_ascii_spaces_before(">   - item", 4), 3, "spaces after quote")

print("list_item_prefix_spec: OK")
```

Note on columns for `"- [ ] buy"`: characters ` - [ ] ` are cols 0–5 if after_markers is past the checkbox (`]` at col 4, often +1 space → 5). Adjust expected `after_markers_col` / results in the spec to match the exact byte columns you document in comments if a fixture differs; the helper itself must be: scan from `after_markers_col` for first `[^%s]` (use Lua pattern on `line:sub(after_markers_col + 1)` and add offset).

- [ ] **Step 2: Run spec to verify it fails**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/list_item_prefix_spec.lua
```

Expected: error that helpers are nil / not a function.

- [ ] **Step 3: Implement helpers in `utils.lua`**

Append to `lua/markdown-tasks/utils.lua`:

```lua
---0-based column of first non-whitespace at or after `after_markers_col`, or `#line` if none.
---@param line string
---@param after_markers_col integer
---@return integer
function M.list_item_content_start_col(line, after_markers_col)
	if after_markers_col < 0 then
		after_markers_col = 0
	end
	if after_markers_col > #line then
		return #line
	end
	local tail = line:sub(after_markers_col + 1)
	local non_ws = tail:find("%S")
	if not non_ws then
		return #line
	end
	return after_markers_col + non_ws - 1
end

---@param cursor_col integer
---@param content_start_col integer
---@return boolean
function M.is_cursor_at_list_item_start(cursor_col, content_start_col)
	return cursor_col < content_start_col
end

---Count consecutive ASCII spaces (` `) immediately before 0-based `col`.
---@param line string
---@param col integer
---@return integer
function M.count_ascii_spaces_before(line, col)
	local n = 0
	local i = col
	while i > 0 do
		local ch = line:sub(i, i)
		if ch ~= " " then
			break
		end
		n = n + 1
		i = i - 1
	end
	return n
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/list_item_prefix_spec.lua
```

Expected: `list_item_prefix_spec: OK`

If fixture columns for the task-checkbox cases disagree with treesitter later, keep the helper semantics and fix only the fixture numbers so they match the documented `after_markers_col`.

- [ ] **Step 5: Commit**

```bash
git add lua/markdown-tasks/utils.lua tests/list_item_prefix_spec.lua
git commit -m "$(cat <<'EOF'
Add list-item prefix column helpers for Tab indent.

EOF
)"
```

---

### Task 2: API indent / outdent

**Files:**
- Modify: `lua/markdown-tasks/api.lua`
- Create: `tests/indent_list_item_smoke.lua`

**Interfaces:**
- Consumes: `utils.list_item_content_start_col`, `utils.is_cursor_at_list_item_start`, `utils.count_ascii_spaces_before`, `M.get_list_item`, `ListItemDecorator:marker` / `:task_marker`
- Produces:
  - `api.indent_list_item(): boolean` — `true` handled, `false` fall through
  - `api.outdent_list_item(): boolean` — `true` handled (including insufficient-indent no-op), `false` fall through

- [ ] **Step 1: Write the failing smoke**

Create `tests/indent_list_item_smoke.lua`:

```lua
-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/indent_list_item_smoke.lua
-- Requires markdown treesitter parser.
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.bo.filetype = "markdown"
vim.bo.shiftwidth = 2

local function reset(lines, row, col)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.api.nvim_win_set_cursor(0, { row, col })
end

-- Indent at start
reset({ "- item" }, 1, 0)
assert(api.indent_list_item() == true, "indent handled")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "  - item", "indented line")
local r, c = unpack(vim.api.nvim_win_get_cursor(0))
assert(r == 1 and c == 2, "cursor moved with indent, got " .. r .. "," .. c)

-- Not at start → fall through
reset({ "- item" }, 1, 4) -- on 't' of item (approx; adjust if needed)
local before = vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]
assert(api.indent_list_item() == false, "mid-content fallthrough")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == before, "unchanged")

-- Outdent
reset({ "  - item" }, 1, 2)
assert(api.outdent_list_item() == true, "outdent handled")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "- item", "outdented line")

-- Insufficient outdent → handled no-op
reset({ "- item" }, 1, 0)
assert(api.outdent_list_item() == true, "outdent at zero handled")
assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "- item", "unchanged at zero")

-- Children not moved
reset({ "- parent", "  - child" }, 1, 0)
assert(api.indent_list_item() == true, "indent parent")
local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "  - parent", "parent indented")
assert(lines[2] == "  - child", "child unchanged")

print("indent_list_item_smoke: OK")
```

Tune the mid-content cursor column after a quick interactive check if `4` is still on the marker/prefix for `"- item"` (content `item` starts at col 2; col 4 is on `e` — fine).

- [ ] **Step 2: Run smoke to verify it fails**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/indent_list_item_smoke.lua
```

Expected: error that `indent_list_item` is nil / not a function.

- [ ] **Step 3: Implement API**

In `lua/markdown-tasks/api.lua`, add (keep existing functions; place new ones near other list helpers):

```lua
---@private
---@return integer
function M.list_indent_step()
	return vim.fn.shiftwidth()
end

---Column just past marker / task marker on the marker row.
---@private
---@param list_item markdown-tasks.decorators.ListItemDecorator
---@return integer? after_markers_col
---@return markdown-tasks.decorators.TSNodeDecorator? marker
function M.after_list_markers_col(list_item)
	local marker = list_item:marker()
	if not marker then
		return nil, nil
	end
	local after = marker.end_col
	local task = list_item:task_marker()
	if task then
		after = task.end_col
	end
	return after, marker
end

---@private
---@return boolean
function M.at_list_item_start()
	ts_utils.parse()
	local cursor_row, cursor_col = utils.get_zero_indexed_cursor()
	local list_item = M.get_list_item(cursor_row)
	if not list_item then
		return false
	end
	local after, marker = M.after_list_markers_col(list_item)
	if not marker or marker.start_row ~= cursor_row then
		return false
	end
	local line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false)[1] or ""
	local content_start = utils.list_item_content_start_col(line, after)
	return utils.is_cursor_at_list_item_start(cursor_col, content_start)
end

---@private
---@param delta integer positive = indent right
function M.shift_list_item_indent(delta)
	ts_utils.parse()
	local cursor_row, cursor_col = utils.get_zero_indexed_cursor()
	local list_item = M.get_list_item(cursor_row)
	if not list_item then
		return
	end
	local after, marker = M.after_list_markers_col(list_item)
	if not marker or marker.start_row ~= cursor_row then
		return
	end
	local line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false)[1] or ""
	local content_start = utils.list_item_content_start_col(line, after)
	local offset_from_content = cursor_col - content_start

	local col = marker.start_col
	if delta > 0 then
		vim.api.nvim_buf_set_text(0, cursor_row, col, cursor_row, col, { string.rep(" ", delta) })
	elseif delta < 0 then
		local remove = -delta
		vim.api.nvim_buf_set_text(0, cursor_row, col - remove, cursor_row, col, {})
	end

	local new_content_start = content_start + delta
	local new_col = new_content_start + offset_from_content
	if new_col < 0 then
		new_col = 0
	end
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, new_col })
end

---@return boolean handled
function M.indent_list_item()
	if not M.at_list_item_start() then
		return false
	end
	M.shift_list_item_indent(M.list_indent_step())
	return true
end

---@return boolean handled
function M.outdent_list_item()
	if not M.at_list_item_start() then
		return false
	end
	ts_utils.parse()
	local cursor_row = utils.get_zero_indexed_cursor()
	local list_item = M.get_list_item(cursor_row)
	if not list_item then
		return true
	end
	local _, marker = M.after_list_markers_col(list_item)
	if not marker then
		return true
	end
	local line = vim.api.nvim_buf_get_lines(0, cursor_row, cursor_row + 1, false)[1] or ""
	local step = M.list_indent_step()
	local available = utils.count_ascii_spaces_before(line, marker.start_col)
	if available < step then
		return true
	end
	M.shift_list_item_indent(-step)
	return true
end
```

`at_list_item_start` already parses; `outdent_list_item` may re-parse before reading spaces — that is fine. Avoid calling `shift_list_item_indent` when `available < step`.

- [ ] **Step 4: Run smoke to verify it passes**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/indent_list_item_smoke.lua
```

Expected: `indent_list_item_smoke: OK`

Also re-run:

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/list_item_prefix_spec.lua
```

Expected: `list_item_prefix_spec: OK`

- [ ] **Step 5: Commit**

```bash
git add lua/markdown-tasks/api.lua tests/indent_list_item_smoke.lua
git commit -m "$(cat <<'EOF'
Add indent_list_item and outdent_list_item API.

EOF
)"
```

---

### Task 3: Insert-mode expr keymaps

**Files:**
- Modify: `lua/markdown-tasks/init.lua`

**Interfaces:**
- Consumes: `api.indent_list_item(): boolean`, `api.outdent_list_item(): boolean`
- Produces: buffer-local `i_<Tab>` / `i_<S-Tab>` expr maps on attach

- [ ] **Step 1: Add keymaps in `on_attach`**

In `lua/markdown-tasks/init.lua`, inside `M.on_attach(buf)` after existing maps:

```lua
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
```

If fallthrough does not insert a tab in a quick manual check, change the return to `"\<Tab>"` / `"\<S-Tab>"` (Neovim expr escaping). Prefer verifying with `:imap <Tab>` / a scratch markdown buffer rather than guessing.

- [ ] **Step 2: Manual checklist (no automated keymap test required)**

In a markdown buffer with the plugin loaded:

1. `- item` with cursor on `-` → `<Tab>` → `  - item`, cursor offset preserved  
2. Same → `<S-Tab>` → back to `- item`  
3. `- item` with cursor on `i` of `item` → `<Tab>` inserts a normal tab / indent (fallthrough), line does not gain leading spaces before `-`  
4. `- item` at col 0 → `<S-Tab>` no-op (stays `- item`)  
5. `- [ ] task` with cursor inside `[ ]` → `<Tab>` indents  

- [ ] **Step 3: Re-run automated tests**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/list_item_prefix_spec.lua
nvim --headless -u NONE -c "set rtp+=." -l tests/indent_list_item_smoke.lua
```

Expected: both print `OK`

- [ ] **Step 4: Commit**

```bash
git add lua/markdown-tasks/init.lua
git commit -m "$(cat <<'EOF'
Map insert Tab/Shift-Tab to list indent when at item start.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Tab indent / S-Tab outdent at prefix start | 2, 3 |
| `shiftwidth()` step, ASCII spaces only | 2 |
| Current line only | 2 (smoke) |
| Fall through when not at start | 2, 3 |
| Insufficient outdent no-op handled | 2 |
| Cursor relative to content | 2 |
| No blockquote special case | 2 (insert at marker.start_col) |
| Buffer-local expr maps | 3 |
| Pure prefix helpers tested | 1 |
