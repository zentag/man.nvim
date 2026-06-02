# man.nvim

Discover local man pages from Neovim with Telescope and open selections through Neovim's built-in `:Man` command.

## Setup

```lua
require('telescope').setup()
require('man_nvim').setup()
```

## Usage

```vim
:Telescope man
```

Entries come from `apropos .`, are sorted by man section, and keep section labels in the searchable text. Use queries like `3 printf` to narrow by section and name.

Telescope mappings:

- `<CR>` opens with `:vertical Man {section} {name}` and focuses the man window.
- `<C-x>` opens with regular `:Man`, matching the horizontal split-oriented picker habit.
- `<C-v>` opens with `:vertical Man`.
- `<C-t>` opens with `:tab Man`.

The Lua module is `man_nvim` to avoid shadowing Neovim's built-in `require('man')`, which `:Man` depends on.
