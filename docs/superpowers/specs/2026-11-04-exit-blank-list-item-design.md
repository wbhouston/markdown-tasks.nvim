# Exit blank list item on new line

## Problem

`markdown-tasks.nvim` continues lists after `<CR>` / `o` / `O` by inserting a newline and then running `toggle_list_item`, which copies list markers onto the new line. Pressing Enter on an already blank list item (marker only) creates another blank item instead of leaving the list. Users expect a second Enter on an empty item to exit the list.

## Goals

- On `<CR>` or `o`, if the line being left is a blank list item, clear that blank item to an empty separator line and leave the cursor on the following empty line at column 0 (no markers, no indent).
- Nested lists and blockquotes: always full exit to column 0 (no one-level demotion).
- `O` and `<leader>tl` keep current `toggle_list_item` behavior (no exit-on-blank).

## Non-goals

- Demoting nested items one level at a time (VS Code / Notion style).
- Changing how markers are chosen when continuing a list.
- Adding a test harness in this change (manual checklist only).

## Behavior

After `<CR>` or `o` has inserted a new line, a new handler runs with the cursor on that new line.

### Blank list item

The **previous** line is blank when it has a list marker prefix and nothing but optional whitespace after that prefix. The prefix includes:

- Unordered markers: `-`, `*`, `+`
- Ordered markers: `1.`, `2)`, etc. (whatever the buffer already uses)
- Optional task checkbox after the marker: `[ ]`, `[x]`, `[X]`
- Leading indent and/or blockquote `>` on that line do not count as content

Examples that **are** blank: `-`, `- `, `  - [ ]`, `> - [x] `, `1. `

Examples that **are not** blank: `- hello`, `- [ ] buy milk`

### Exit path

When the previous line is a blank list item:

1. Clear the previous blank list-item line to a plain empty string (no markers, no indent) — this is the blank separator under the list.
2. Ensure the current line is a plain empty string (no markers, no indent).
3. Place the cursor at column 0 on the current line (so one empty newline sits between the list and the cursor).

Mid-list exit intentionally leaves empty lines between siblings (which splits the markdown list).

### Continue path

When the previous line is not a blank list item, keep today’s continue-list behavior (add markers to the new line from the preferred neighboring list item).

## Architecture

### New API: `on_new_line`

Add `api.on_new_line()` in `lua/markdown-tasks/api.lua`:

```
on_new_line()
  → if previous line is blank list item → exit_blank_list_item()
  → else → add_list_item_markers_to_line(cursor_row)
```

`on_new_line` must not call full `toggle_list_item`, so a post-newline continue never takes the remove-markers branch.

Private helpers:

- `is_blank_list_item(row)` — true when the line has a list/task marker prefix and the remainder is only whitespace.
- `exit_blank_list_item()` — clear previous row to `""` (separator); set current line to `""`; set cursor to column 0 on the current line.

Prefer reusing `get_list_item` / `ListItemDecorator` for marker bounds where helpful; blankness may use line text relative to those bounds so empty-line treesitter quirks do not block detection.

### Command dispatch

Expose `on_new_line` through the existing `MarkdownTasks` user command (`api[method]` routing in `lua/markdown-tasks/command.lua` needs no structural change).

### Keymaps (`lua/markdown-tasks/init.lua`)

| Mapping     | Command                                      |
|-------------|----------------------------------------------|
| `i_<CR>`    | `<cr><cmd>MarkdownTasks on_new_line<cr>`     |
| `n_o`       | `o<cmd>MarkdownTasks on_new_line<cr>`        |
| `n_O`       | unchanged → `toggle_list_item`               |
| `<leader>tl`| unchanged → `toggle_list_item`               |

### `toggle_list_item`

Leave behavior as-is for `O` and leader toggle. Both continue paths use the existing private `add_list_item_markers_to_line`; no intentional behavior change for `O`.

## Error handling

If parse fails or the previous row is out of range: fall through quietly (no notify/throw), matching the plugin’s current style.

## Manual test checklist

- Blank `- ` then `<CR>` → empty separator under the list, cursor on following empty col-0 line
- Nested `  - ` blank then `<CR>` → empty separator + cursor on following empty col-0 (not demoted)
- Blank `- [ ] ` then `<CR>` → exit
- Blank `1. ` then `<CR>` → exit
- Mid-list blank exit → empty line between siblings
- Non-blank item then `<CR>` → continues list (unchanged)
- `o` on blank item → same exit as `<CR>`
- `O` on/above blank item → still continues list (no exit)
- Blockquote `> - ` blank then `<CR>` → empty col-0 (no `>`)
