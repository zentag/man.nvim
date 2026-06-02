# AGENTS.md

## Project State
- This repo is being bootstrapped as `man.nvim`, a Neovim man-page discovery picker based on `../rfc.nvim`.
- Current work is on the local `mini.picker` branch; `../rfc.nvim` has local `main` and remote `origin/mini-pick-conversion` for template comparison.
- The plugin module is `man_nvim`, not `man`, because `lua/man/init.lua` would shadow Neovim's built-in `require('man')` used by `:Man`.

## Commands
- Run tests with `make test`; it starts Neovim headless through `lua/tests/minimal.lua` and Plenary's test harness.
- Format Lua with StyLua using `.stylua.toml`: 2-space indents, Unix endings, `AutoPreferSingle`, sorted requires, `column_width = 100`.

## Implementation Notes
- `lua/man_nvim/init.lua` registers `:Pick man` through `require('mini.pick').registry.man`.
- Picker items come from `apropos .`; parser tests should cover noisy `makewhatis:` output, aliases, section sorting, and `:Man` command construction before UI behavior.
- Keep selection delegated to Neovim's `:Man` command so built-in man buffers, mappings, and navigation stay intact.
- Mini.pick has no section-header row API; keep section discoverability in item text and sorting rather than adding unselectable header items.
- If/when converting to Telescope, use `../rfc.nvim` `main` only as a scaffold and preserve the `man_nvim` module-name constraint.
