# Tab / Shift-Tab indent and outdent list items

## Problem

In insert mode, `<Tab>` and `<S-Tab>` do not nest or unnest markdown list items. Users editing lists expect Tab at the start of an item to indent it (e.g. `- item` → `  - item`) and Shift-Tab to outdent, while leaving normal Tab / Shift-Tab behavior everywhere else.

## Goals

- In insert mode, when the cursor is at the start of a list item, `<Tab>` indents and `<S-Tab>` outdents the **current line only**.
- Indent step follows `'shiftwidth'` (Neovim `shiftwidth()` so `shiftwidth=0` uses `'tabstop'`).
- When not at the start of a list item, fall through to normal insert-mode `<Tab>` / `<S-Tab>`.
- After a successful indent/outdent, keep the cursor’s offset relative to the post-prefix content.

## Non-goals

- Moving nested children with the parent.
- Renumbering ordered lists.
- Normal-mode maps.
- Blockquote-specific indent policy (no special case; spaces go before the marker node).
- Inserting tab characters / honoring `'expandtab'` beyond “always use spaces of length `shiftwidth()`”.
- Changing snippet / completion plugin behavior beyond normal key fallthrough.

## Behavior

### When the key is handled

| Key | At start of list item | Otherwise |
|-----|----------------------|-----------|
| `<Tab>` | Insert `shiftwidth()` spaces immediately before the list marker | Fall through to normal `<Tab>` |
| `<S-Tab>` | If at least `shiftwidth()` ASCII spaces exist immediately before the marker, remove that many; otherwise **no-op** (do not fall through). Tabs or other whitespace do not count toward the removable step in v1. | Fall through to normal `<S-Tab>` |

Only the current line changes. Nested children are left as-is.

### “At start” of a list item

The cursor is on the list item’s **marker row** (same row as the list/task markers), and the cursor column is still in the **prefix zone**:

1. At or before the list marker (`-`, `*`, `+`, ordered `1.` / `2)`, etc.)
2. Inside the task checkbox when present (`[ ]`, `[x]`, `[X]`)
3. In whitespace after the marker (and checkbox if any), before the first content character

Examples (cursor `|`):

- `| - item`, `-| item`, `- |item` → at start (before/on marker or in marker-adjacent prefix)
- `- [ |] buy`, `- [|] buy` → at start (in task status)
- `- [ ]   |buy` → at start (in whitespace after prefix)
- `- [ ]   b|uy` → **not** at start
- Continuation / body lines of a multi-line item (marker on a different row) → **not** at start → fall through

Formally: `content_start_col` is the column of the first non-whitespace character after the marker (and task marker if present). At start when `cursor_col < content_start_col`. If there is no content yet, the prefix zone extends through trailing whitespace after the markers; cursor anywhere in that trailing whitespace (or before) counts as at start.

### Cursor after a successful change

Preserve the cursor’s offset relative to the first content character. If the line has no content yet, preserve offset relative to the end of the prefix (marker / task marker / following whitespace). Absolute column alone is not the target.

### Blockquotes

No special case. Indent/outdent inserts or removes spaces at the list marker’s start column, so e.g. `> - item` naturally becomes `>   - item` when the marker sits after the quote prefix.

## Architecture

### Approach

Buffer-local insert-mode **`<expr>`** maps call shared API functions. The API returns whether the key was handled; the map returns `""` when handled, or the original key for fallthrough.

### API (`lua/markdown-tasks/api.lua`)

Public:

- `indent_list_item()` → `true` if handled (including successful indent), `false` if caller should fall through
- `outdent_list_item()` → `true` if handled (successful outdent **or** insufficient-indent no-op), `false` if fall through

Private helpers:

- `at_list_item_start()` — `ts_utils.parse()`, `get_list_item`, require marker row == cursor row; use `ListItemDecorator:marker()` / `:task_marker()` plus line text for the whitespace-after-prefix zone
- `list_indent_step()` — `vim.fn.shiftwidth()`
- `indent_current_list_item()` / `outdent_current_list_item()` — `nvim_buf_set_text` to insert/delete spaces at `marker.start_col`; adjust cursor for relative offset

Expr-map contract:

| Situation | API return | Map returns |
|-----------|------------|-------------|
| Not a list item / not at start | `false` | `"\<Tab>"` / `"\<S-Tab>"` |
| At start + indent | `true` | `""` |
| At start + outdent with enough spaces | `true` | `""` |
| At start + outdent without enough spaces | `true` (no-op) | `""` |

Both methods remain callable via the existing `MarkdownTasks` user command for debugging.

### Keymaps (`lua/markdown-tasks/init.lua` `on_attach`)

Buffer-local expr maps (new maps should be buffer-local even though some existing maps are global):

```lua
vim.keymap.set("i", "<Tab>", function()
  return require("markdown-tasks.api").indent_list_item() and "" or "<Tab>"
end, { expr = true, buffer = buf })

vim.keymap.set("i", "<S-Tab>", function()
  return require("markdown-tasks.api").outdent_list_item() and "" or "<S-Tab>"
end, { expr = true, buffer = buf })
```

Use whatever string form Neovim requires for expr fallthrough (`"<Tab>"` vs `"\<Tab>"`) so the default key is actually emitted.

### Detection details

Reuse `ListItemDecorator` marker / task marker bounds. Do not reimplement marker regex for the happy path. Line text is only needed to find where prefix whitespace ends and content begins.

## Error handling and edge cases

- Missing treesitter / no list item node → fall through.
- Insufficient leading spaces before marker on outdent → no-op, consume key.
- Always insert/remove **spaces** (not tab characters) of length `list_indent_step()`.
- Single `nvim_buf_set_text` call per action so undo stays one step.

## Testing

- Specs for prefix-zone / “at start” boundaries: before marker, in task status, in trailing prefix whitespace, on first content character, continuation line.
- Smoke or API-level checks: indent text + cursor offset; outdent text + cursor offset; outdent-at-zero no-op returns handled; not-at-start returns fallthrough (`false`).
