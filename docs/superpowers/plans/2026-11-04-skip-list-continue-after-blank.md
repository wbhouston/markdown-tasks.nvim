# Skip List Continue After Blank Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a blank separator under a list, `<CR>` / `o` / `O` leave plain empty lines; `<leader>tl` still toggles, inventing `- ` when there is no list to copy from.

**Architecture:** Add `utils.is_empty_or_whitespace_line`. Extract `continue_list_item_on_new_line` (skip if previous empty/whitespace, else `add_list_item_markers_to_line`). `on_new_line` keeps blank-list exit then calls that helper. Point `O` at the helper. In `toggle_list_item`, when the old fall-through would no-op, prefix basic `- `.

**Tech Stack:** Neovim Lua plugin, vim.api buffer edits, existing `MarkdownTasks` command dispatch, headless `nvim -l` for pure-helper and smoke checks.

## Global Constraints

- Empty/whitespace previous on new-line path → no markers (quiet return).
- Blank-list exit stays on `<CR>` / `o` only; `O` uses continue-or-skip only.
- Do not put the empty-previous guard inside `add_list_item_markers_to_line`.
- Basic `- ` fallback lives only in `toggle_list_item`, not in the new-line path.
- Fail quietly on out-of-range / missing previous row.
- No full test harness; headless scripts for pure helper + targeted smokes; manual checklist for keymaps.

## File Structure

| File | Responsibility |
|------|----------------|
| `lua/markdown-tasks/utils.lua` | Add `is_empty_or_whitespace_line(line)` |
| `lua/markdown-tasks/api.lua` | Add `continue_list_item_on_new_line`; wire `on_new_line`; basic `- ` in `toggle_list_item` |
| `lua/markdown-tasks/init.lua` | Point `O` at `continue_list_item_on_new_line` |
| `tests/is_empty_or_whitespace_line_spec.lua` | Headless assertions for the pure helper |
| `tests/continue_list_item_on_new_line_smoke.lua` | Empty-previous skip smoke |
| `tests/toggle_list_item_basic_smoke.lua` | Basic `- ` fallback smoke |
| `lua/markdown-tasks/command.lua` | No change (already dispatches `api[method]`) |

---

### Task 1: Pure empty/whitespace line detector

**Files:**
- Modify: `lua/markdown-tasks/utils.lua`
- Create: `tests/is_empty_or_whitespace_line_spec.lua`

**Interfaces:**
- Consumes: none
- Produces: `utils.is_empty_or_whitespace_line(line: string): boolean`

- [ ] **Step 1: Write the failing spec**

Create `tests/is_empty_or_whitespace_line_spec.lua`:

```lua
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
```

- [ ] **Step 2: Run spec to verify it fails**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/is_empty_or_whitespace_line_spec.lua
```

Expected: error that `is_empty_or_whitespace_line` is nil / not a function.

- [ ] **Step 3: Implement helper**

In `lua/markdown-tasks/utils.lua`, add:

```lua
---True when `line` is empty or only whitespace.
---@param line string
---@return boolean
function M.is_empty_or_whitespace_line(line)
	return line:match("^%s*$") ~= nil
end
```

- [ ] **Step 4: Run spec to verify it passes**

Same command as Step 2. Expected: `is_empty_or_whitespace_line_spec: OK`

- [ ] **Step 5: Commit**

```bash
git add lua/markdown-tasks/utils.lua tests/is_empty_or_whitespace_line_spec.lua
git commit -m "$(cat <<'EOF'
Add empty/whitespace line detector for blank-separator skip.

EOF
)"
```

---

### Task 2: `continue_list_item_on_new_line` + wire `on_new_line` and `O`

**Files:**
- Modify: `lua/markdown-tasks/api.lua`
- Modify: `lua/markdown-tasks/init.lua`
- Create: `tests/continue_list_item_on_new_line_smoke.lua`

**Interfaces:**
- Consumes: `utils.is_empty_or_whitespace_line`, `M.add_list_item_markers_to_line`, `M.is_blank_list_item`, `M.exit_blank_list_item`
- Produces: `M.continue_list_item_on_new_line()` (public, for keymap/command); `on_new_line` calls it after blank-list exit

- [ ] **Step 1: Write failing smoke for empty-previous skip**

Create `tests/continue_list_item_on_new_line_smoke.lua`:

```lua
-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/continue_list_item_on_new_line_smoke.lua
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "- foo", "", "" })
vim.api.nvim_win_set_cursor(0, { 3, 0 })
api.continue_list_item_on_new_line()

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1] == "- foo", "line 1 preserved")
assert(lines[2] == "", "separator preserved")
assert(lines[3] == "", "cursor line stays plain empty, got " .. vim.inspect(lines[3]))

print("continue_list_item_on_new_line_smoke: OK")
```

- [ ] **Step 2: Run smoke to verify it fails**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/continue_list_item_on_new_line_smoke.lua
```

Expected: error that `continue_list_item_on_new_line` is nil.

- [ ] **Step 3: Implement API + keymap**

In `lua/markdown-tasks/api.lua`, replace the tail of `on_new_line` and add:

```lua
function M.continue_list_item_on_new_line()
	ts_utils.parse()

	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1
	if previous_row < 0 then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(0, previous_row, previous_row + 1, false)
	local previous_line = lines[1]
	if not previous_line or utils.is_empty_or_whitespace_line(previous_line) then
		return
	end

	M.add_list_item_markers_to_line(cursor_row)
end

function M.on_new_line()
	ts_utils.parse()

	local cursor_row = utils.get_zero_indexed_cursor()
	local previous_row = cursor_row - 1

	if previous_row >= 0 and M.is_blank_list_item(previous_row) then
		M.exit_blank_list_item()
		return
	end

	M.continue_list_item_on_new_line()
end
```

Note: `continue_list_item_on_new_line` calls `ts_utils.parse()` again when invoked from `on_new_line` — acceptable; keeps the `O` entry self-contained.

In `lua/markdown-tasks/init.lua`, change the `O` mapping:

```lua
vim.api.nvim_set_keymap("n", "O", "O<cmd>MarkdownTasks continue_list_item_on_new_line<cr>", {})
```

Leave `<CR>` and `o` on `on_new_line`.

- [ ] **Step 4: Run smoke to verify it passes**

Same command as Step 2. Expected: `continue_list_item_on_new_line_smoke: OK`

Also re-run prior specs:

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/is_empty_or_whitespace_line_spec.lua
nvim --headless -u NONE -c "set rtp+=." -l tests/is_blank_list_line_spec.lua
nvim --headless -u NONE -c "set rtp+=." -l tests/exit_blank_list_item_smoke.lua
```

Expected: all print OK.

- [ ] **Step 5: Commit**

```bash
git add lua/markdown-tasks/api.lua lua/markdown-tasks/init.lua tests/continue_list_item_on_new_line_smoke.lua
git commit -m "$(cat <<'EOF'
Skip list continue when the previous line is blank.

EOF
)"
```

---

### Task 3: Basic `- ` fallback in `toggle_list_item`

**Files:**
- Modify: `lua/markdown-tasks/api.lua`
- Create: `tests/toggle_list_item_basic_smoke.lua`

**Interfaces:**
- Consumes: existing `get_list_item`, `add_list_item_markers_to_line`, `remove_list_item_markers_from_line`
- Produces: private `add_basic_list_item_marker(cursor_row)`; `toggle_list_item` uses it on former no-op path

- [ ] **Step 1: Write failing smoke**

Create `tests/toggle_list_item_basic_smoke.lua`:

```lua
-- Run: nvim --headless -u NONE -c "set rtp+=." -l tests/toggle_list_item_basic_smoke.lua
-- Requires markdown treesitter parser available to the headless nvim.
local api = require("markdown-tasks.api")

vim.cmd("enew")
vim.bo.filetype = "markdown"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
api.toggle_list_item()

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(lines[1]:match("^%- hello$") or lines[1]:match("^%-hello$") or lines[1]:match("^%- "),
	"expected basic list marker on line, got " .. vim.inspect(lines[1]))
-- Spec: prefix `- ` onto current line content
assert(lines[1] == "- hello", "expected '- hello', got " .. vim.inspect(lines[1]))

print("toggle_list_item_basic_smoke: OK")
```

- [ ] **Step 2: Run smoke to verify it fails**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/toggle_list_item_basic_smoke.lua
```

Expected: assertion failure (line still `hello`) or parser error if markdown TS missing — if parser missing, stop and ask; otherwise proceed on assertion fail.

- [ ] **Step 3: Implement basic fallback**

In `lua/markdown-tasks/api.lua`, add private helper and update `toggle_list_item`:

```lua
---@private
---@param cursor_row integer
function M.add_basic_list_item_marker(cursor_row)
	local first_node_on_cursor_row = vim.treesitter.get_node({ pos = { cursor_row, 0 } })
	local replace_start = 0
	if first_node_on_cursor_row ~= nil and first_node_on_cursor_row:type() == "block_continuation" then
		_, replace_start = first_node_on_cursor_row:end_()
	end

	vim.api.nvim_buf_set_text(0, cursor_row, replace_start, cursor_row, replace_start, { "- " })
	local cursor_eol = utils.get_eol(cursor_row)
	vim.api.nvim_win_set_cursor(0, { cursor_row + 1, cursor_eol })
end

function M.toggle_list_item()
	ts_utils.parse()

	local cursor_row, _ = utils.get_zero_indexed_cursor()
	local cursor_list_item = M.get_list_item(cursor_row)

	if cursor_list_item then
		if cursor_list_item.start_row == cursor_row then
			M.remove_list_item_markers_from_line(cursor_list_item)
		else
			M.add_list_item_markers_to_line(cursor_row)
		end
	else
		local next_line_cursor_item = M.get_list_item(cursor_row + 1)
		if next_line_cursor_item then
			M.add_list_item_markers_to_line(cursor_row)
		else
			M.add_basic_list_item_marker(cursor_row)
		end
	end
end
```

- [ ] **Step 4: Run smoke + prior tests**

```bash
nvim --headless -u NONE -c "set rtp+=." -l tests/toggle_list_item_basic_smoke.lua
nvim --headless -u NONE -c "set rtp+=." -l tests/continue_list_item_on_new_line_smoke.lua
nvim --headless -u NONE -c "set rtp+=." -l tests/is_empty_or_whitespace_line_spec.lua
nvim --headless -u NONE -c "set rtp+=." -l tests/exit_blank_list_item_smoke.lua
```

Expected: all OK.

- [ ] **Step 5: Commit**

```bash
git add lua/markdown-tasks/api.lua tests/toggle_list_item_basic_smoke.lua
git commit -m "$(cat <<'EOF'
Default toggle_list_item to a basic unordered marker.

EOF
)"
```

---

## Manual test checklist (after implementation)

- Post-exit empty → `<CR>` / `o` / `O` → plain empty, no markers
- Non-blank item → `<CR>` / `o` → continues list
- Blank item → `<CR>` / `o` exit; `O` does not exit
- Whitespace-only previous → new-line keys add no markers
- `<leader>tl` on plain line / empty previous / no nearby list → `- …`
- `<leader>tl` on list-item start → removes markers
- `<leader>tl` near existing list → copies neighbor when applicable
