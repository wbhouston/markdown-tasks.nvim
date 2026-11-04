# Skip list continue after blank separator

## Problem

After exiting a blank list item, the buffer looks like:

```markdown
- item

|cursor|
```

A second `<CR>`, `o`, or `O` still turns the new line into a list item. That happens because `add_list_item_markers_to_line` consults `get_list_item` on the previous row, and empty lines still resolve to the list above via treesitter. Users expect a blank separator to mean “left the list”: further newlines stay plain.

Separately, `<leader>tl` (“toggle list item”) should still work on a plain line even when the previous line is empty or there are no other lists in the buffer. A shared early-return inside `add_list_item_markers_to_line` would break that.

## Goals

- When `<CR>`, `o`, or `O` creates a new line whose immediate previous line is empty or whitespace-only, do not add list markers; leave a plain empty line.
- Keep blank-list exit on `<CR>` / `o` unchanged; `O` still does not exit on a blank list item.
- `<leader>tl` remains able to toggle: remove markers on a list-item start row, copy from a neighbor when available, or insert a basic unordered marker (`- `) when there is nothing to copy from (including empty previous / no lists in the buffer).

## Non-goals

- Changing how markers are chosen when continuing a non-blank list item.
- Demoting nested lists one level at a time.
- Fixing `get_list_item` so empty lines never resolve to the previous list item (broader treesitter quirk; out of scope).
- Remapping `O` onto full `on_new_line` exit-on-blank behavior.

## Behavior

### New-line keys (`<CR>`, `o`, `O`)

After the newline is inserted and the cursor sits on the new line:

1. **Blank-list exit** (`<CR>` / `o` only, existing): if the previous line is a blank list item (marker only), clear it to a separator and leave the cursor on a plain empty line — unchanged.
2. **Blank-separator skip** (all three keys): if the previous line is empty or whitespace-only (`^%s*$`), do nothing further (no markers).
3. **Continue**: otherwise add list markers from the preferred neighboring list item (unchanged).

`O` uses step 2 and 3 only (no step 1).

### `<leader>tl` (`toggle_list_item`)

Unchanged for remove / continue-from-neighbor. New fallback: when the current line is not already a list-item start to strip, and no neighboring list item supplies markers to copy, insert a basic unordered list prefix (`- `) on the current line and place the cursor after it.

## Architecture

### Empty previous helper

Add `utils.is_empty_or_whitespace_line(line)` → true for `""` and whitespace-only (`^%s*$`). Callers treat a missing/out-of-range previous row as “skip” without requiring the helper to accept `nil`.

### New-line path

```
on_new_line()
  → parse
  → if previous is blank list item → exit_blank_list_item(); return
  → continue_list_item_on_new_line()

continue_list_item_on_new_line()
  → if previous row missing or empty/whitespace → return
  → add_list_item_markers_to_line(cursor_row)
```

Do **not** put the empty/whitespace guard inside `add_list_item_markers_to_line`, so toggle can still copy from a neighbor (including via today’s empty-line treesitter association) or apply the basic fallback.

### `O` keymap

Change `n_O` from `toggle_list_item` to `continue_list_item_on_new_line` (after `O` inserts the line). `<CR>` / `o` keep `on_new_line`.

| Mapping      | Behavior                                      |
|--------------|-----------------------------------------------|
| `i_<CR>`     | newline → `on_new_line` (exit + skip + continue) |
| `n_o`        | `o` → `on_new_line`                           |
| `n_O`        | `O` → `continue_list_item_on_new_line` (no blank exit) |
| `<leader>tl` | `toggle_list_item` (remove / copy / basic `- `) |

### `toggle_list_item` basic fallback

When today’s logic would leave the line unchanged — not a list-item start row to strip, and no preferred neighbor for `add_list_item_markers_to_line` (no list association on cursor/neighbors) — prefix a basic unordered marker `- ` onto the current line (after an existing `block_continuation` if present, same replace-start rule as continue). Set the cursor to end of line.

This fallback is only for inventing a list when none is available to copy. If treesitter still associates the cursor line with a list above across a blank, toggle may still copy that neighbor; new-line keys will not, because they return on empty/whitespace previous before calling `add_list_item_markers_to_line`.

`add_list_item_markers_to_line` stays “copy from preferred neighbor or return”; the basic `- ` default lives only in `toggle_list_item`.

## Error handling

Out-of-range previous row on the new-line path: treat as skip/no-op (quiet), matching the plugin’s existing style. Missing buffer line: same.

## Manual test checklist

- Post-exit empty line → `<CR>` / `o` / `O` → plain empty line, no markers
- Non-blank list item → `<CR>` / `o` → continues list (unchanged)
- Blank list item → `<CR>` / `o` → exit (unchanged); `O` → does not exit
- Whitespace-only previous line → new-line keys add no markers
- `<leader>tl` on plain line with empty previous / no nearby list → becomes `- …`
- `<leader>tl` on list-item start row → still removes markers
- `<leader>tl` between/near existing list items → still copies neighbor markers when applicable
