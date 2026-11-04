# Exit Blank List Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When `<CR>` or `o` leaves a blank list item, remove that item and land on an empty column-0 line instead of continuing the list.

**Architecture:** Keep the existing post-newline keymap pattern. Add `api.on_new_line()` that inspects the previous line: if it is a blank list item, delete it and clear the current line to column 0; otherwise call existing `add_list_item_markers_to_line`. Detect blankness with a pure string helper in `utils` so it can be unit-tested without treesitter. Wire only `<CR>` and `o` to the new command; leave `O` and `<leader>tl` on `toggle_list_item`.

**Tech Stack:** Neovim Lua plugin, vim.api buffer edits, existing `MarkdownTasks` command dispatch, optional headless `nvim -l` for pure-helper checks.

## Global Constraints

- Exit always goes to column 0 (no nested demotion, no retained `>`).
- Blank means marker ± optional task checkbox, remainder only whitespace; leading indent/`>` allowed.
- `<CR>` and `o` use `on_new_line`; `O` and `<leader>tl` stay on `toggle_list_item` (no exit-on-blank).
- `on_new_line` must not call full `toggle_list_item`.
- Fail quietly on out-of-range / missing lines (no notify/throw).
- No full test harness; only a tiny headless script for the pure blank-line helper plus manual checklist for integration.

## File Structure

| File | Responsibility |
|------|----------------|
| `lua/markdown-tasks/utils.lua` | Add pure `is_blank_list_line(line)` |
| `lua/markdown-tasks/api.lua` | Add `on_new_line`, private `is_blank_list_item(row)`, private `exit_blank_list_item` |
| `lua/markdown-tasks/init.lua` | Point `<CR>` and `o` at `on_new_line` |
| `tests/is_blank_list_line_spec.lua` | Headless assertions for the pure helper |
| `lua/markdown-tasks/command.lua` | No change (already dispatches `api[method]`) |

---

### Task 1: Pure blank-list-line detector

**Files:**
- Modify: `lua/markdown-tasks/utils.lua`
- Create: `tests/is_blank_list_line_spec.lua`

**Interfaces:**
- Consumes: none
- Produces: `utils.is_blank_list_line(line: string): boolean`

- [ ] **Step 1: Write the failing spec**

Create `tests/is_blank_list_line_spec.lua`:

```lua
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
```

- [ ] **Step 2: Run spec to verify it fails**

Run from repo root:

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/is_blank_list_line_spec.lua
```

Expected: error that `is_blank_list_line` is nil / not a function (or require fails on missing field).

- [ ] **Step 3: Implement `is_blank_list_line`**

In `lua/markdown-tasks/utils.lua`, add:

```lua
---True when `line` is a list/task marker with no content after the prefix.
---Leading whitespace and blockquote `>` markers are ignored as content.
---@param line string
---@return boolean
function M.is_blank_list_line(line)
	if not line or line == "" then
		return false
	end

	-- optional indent + one or more "> " blockquote prefixes, then unordered or ordered marker,
	-- optional task checkbox, then only whitespace to EOL
	local pattern = "^%s*(>%s*)*([%-%*+]|%d+[.)])%s*(%[[ xX]%])?%s*$"
	return line:match(pattern) ~= nil
end
```

- [ ] **Step 4: Run spec to verify it passes**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/is_blank_list_line_spec.lua
```

Expected: prints `is_blank_list_line_spec: OK` and exits 0.

If a case fails, adjust the pattern until all listed examples from the design spec pass; do not weaken the not-blank cases.

- [ ] **Step 5: Commit**

```bash
git add lua/markdown-tasks/utils.lua tests/is_blank_list_line_spec.lua
git commit -m "$(cat <<'EOF'
Add blank list line detector for exit-on-empty behavior.

Pure string check so <CR>/o can tell marker-only lines from real items.
EOF
)"
```

---

### Task 2: `on_new_line` exit and continue paths

**Files:**
- Modify: `lua/markdown-tasks/api.lua`

**Interfaces:**
- Consumes: `utils.is_blank_list_line(line)`, `utils.get_zero_indexed_cursor()`, existing `M.add_list_item_markers_to_line(cursor_row)`, `ts_utils.parse()`
- Produces: `M.on_new_line()`, private `M.is_blank_list_item(row)`, private `M.exit_blank_list_item()`

- [ ] **Step 1: Add private helpers and `on_new_line`**

In `lua/markdown-tasks/api.lua`, after the existing helpers (near `remove_list_item_markers_from_line`), add:

```lua
---@private
---@param row integer zero-based
---@return boolean
function M.is_blank_list_item(row)
	if row < 0 then
		return false
	end
	local lines = vim.api.nvim_buf_get_lines(0, row, row + 1, false)
	local line = lines[1]
	if not line then
		return false
	end
	return utils.is_blank_list_line(line)
end

---@private
function M.exit_blank_list_item()
	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1
	if previous_row < 0 then
		return
	end

	-- Delete the blank list item; the former current line shifts up to previous_row.
	vim.api.nvim_buf_set_lines(0, previous_row, previous_row + 1, false, {})
	vim.api.nvim_buf_set_lines(0, previous_row, previous_row + 1, false, { "" })
	vim.api.nvim_win_set_cursor(0, { previous_row + 1, 0 })
end

function M.on_new_line()
	ts_utils.parse()

	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1

	if previous_row >= 0 and M.is_blank_list_item(previous_row) then
		M.exit_blank_list_item()
		return
	end

	M.add_list_item_markers_to_line(cursor_row)
end
```

Do **not** call `M.toggle_list_item()` from `on_new_line`.

- [ ] **Step 2: Smoke-check dispatch in headless Neovim**

Run:

```bash
nvim --headless -u NONE -c "set rtp+=." -c "lua require('markdown-tasks.command').init()" -c "lua assert(require('markdown-tasks.api').on_new_line)" -c "qa!"
```

Expected: exits 0 with no error (function exists; command module still loads).

- [ ] **Step 3: Manual buffer smoke for exit path**

In a disposable nvim session with the plugin on `rtp`:

1. Open a markdown buffer, enable filetype markdown, call `require("markdown-tasks").setup()`.
2. Insert:

```markdown
- foo
- 
```

(cursor on the blank `- ` line after setup keymaps, or manually: press `o` / simulate by inserting a newline under the blank item then `:MarkdownTasks on_new_line`)

3. After `on_new_line` on the new empty line under a blank `- `, buffer should be:

```markdown
- foo

```

with cursor on the empty line at column 0.

4. Under a non-blank `- foo` then newline + `on_new_line`, should still get a continued `- ` (or equivalent marker) line.

- [ ] **Step 4: Commit**

```bash
git add lua/markdown-tasks/api.lua
git commit -m "$(cat <<'EOF'
Add on_new_line to exit lists on blank items.

Removes the empty marker line and continues the list only when content remains.
EOF
)"
```

---

### Task 3: Wire `<CR>` and `o` keymaps

**Files:**
- Modify: `lua/markdown-tasks/init.lua`

**Interfaces:**
- Consumes: `MarkdownTasks on_new_line` (command → `api.on_new_line`)
- Produces: insert `<CR>` and normal `o` invoke exit-capable handler; `O` / `<leader>tl` unchanged

- [ ] **Step 1: Update keymaps**

In `lua/markdown-tasks/init.lua` `M.on_attach`, change only the `<CR>` and `o` lines:

```lua
	vim.api.nvim_set_keymap("i", "<cr>", "<cr><cmd>MarkdownTasks on_new_line<cr>", {})
	vim.api.nvim_set_keymap("n", "o", "o<cmd>MarkdownTasks on_new_line<cr>", {})
	vim.api.nvim_set_keymap("n", "O", "O<cmd>MarkdownTasks toggle_list_item<cr>", {})
	vim.api.nvim_set_keymap("n", "<leader>tl", "<cmd>MarkdownTasks toggle_list_item<cr>", {})
```

- [ ] **Step 2: Run pure helper spec again (regression)**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/is_blank_list_line_spec.lua
```

Expected: `is_blank_list_line_spec: OK`

- [ ] **Step 3: Manual checklist from design spec**

With plugin attached on a markdown buffer, verify each:

| Case | Expected |
|------|----------|
| Blank `- ` then `<CR>` | Empty col-0 line; blank item removed |
| Nested `  - ` blank then `<CR>` | Empty col-0 (not demoted) |
| Blank `- [ ] ` then `<CR>` | Exit |
| Blank `1. ` then `<CR>` | Exit |
| Mid-list blank exit | Empty line between siblings |
| Non-blank item then `<CR>` | Continues list |
| `o` on blank item | Same exit as `<CR>` |
| `O` on/above list | Still continues list (no exit) |
| Blockquote `> - ` blank then `<CR>` | Empty col-0 (no `>`) |

- [ ] **Step 4: Commit**

```bash
git add lua/markdown-tasks/init.lua
git commit -m "$(cat <<'EOF'
Route <CR> and o through on_new_line for blank-list exit.

Leaves O and leader toggle on the previous continue/toggle path.
EOF
)"
```

---

## Spec Coverage (self-review)

| Spec requirement | Task |
|------------------|------|
| Blank detection (marker ± task, whitespace only) | Task 1 |
| Exit: delete blank item, empty col-0 current line | Task 2 |
| Continue via `add_list_item_markers_to_line` | Task 2 |
| Do not call full `toggle_list_item` from `on_new_line` | Task 2 |
| Command dispatch without structural change | Task 2 (existing `api[method]`) |
| `<CR>` / `o` → `on_new_line`; `O` / leader unchanged | Task 3 |
| Full exit (no demotion); blockquote to col 0 | Tasks 1–3 + manual checklist |
| Quiet failure on bad rows | Task 2 (`previous_row < 0` / missing line) |
| Manual checklist | Task 3 Step 3 |
