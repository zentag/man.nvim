local assert = require('luassert')
local man_nvim = require('man_nvim')

local eq = assert.are.same
local isnil = assert.is.Nil

local function with_options(options, fn)
  local original = {}
  for name, value in pairs(options) do
    original[name] = vim.o[name]
    vim.o[name] = value
  end

  local ok, err = pcall(fn)
  for name, value in pairs(original) do
    vim.o[name] = value
  end
  if not ok then error(err) end
end

describe('man.nvim plugin', function()
  it(
    'parses a single apropos entry',
    function()
      eq({
        aliases = { { name = 'printf', section = '1', ref = 'printf(1)' } },
        description = 'formatted output',
        primary = { name = 'printf', section = '1', ref = 'printf(1)' },
      }, man_nvim.parse_line('printf(1)                - formatted output'))
    end
  )

  it(
    'parses aliases from one apropos entry',
    function()
      eq({
        aliases = {
          { name = 'builtin', section = '1', ref = 'builtin(1)' },
          { name = '!', section = '1', ref = '!(1)' },
          { name = '[', section = '1', ref = '[(1)' },
        },
        description = 'shell built-in commands',
        primary = { name = 'builtin', section = '1', ref = 'builtin(1)' },
      }, man_nvim.parse_line('builtin(1), !(1), [(1) - shell built-in commands'))
    end
  )

  it(
    'returns nil for non-apropos noise',
    function()
      isnil(man_nvim.parse_line('makewhatis: /usr/share/man/foo.1: No such file or directory'))
    end
  )

  it('turns apropos output into section-grouped picker items', function()
    local items = man_nvim.make_items({
      'printf(3) - formatted output library function',
      'printf(1) - formatted output command',
      'xprintf(5) - extensible printf',
    })

    eq(
      { 'printf(1)', 'printf(3)', 'xprintf(5)' },
      vim.tbl_map(function(item) return item.ref end, items)
    )
    eq('[1 User commands] printf(1) - formatted output command', items[1].text)
  end)

  it('opens apropos aliases through their canonical page', function()
    local items = man_nvim.make_items({ 'builtin(1), !(1), %(1) - shell built-in commands' })

    eq(
      {
        { ref = '!(1)', target_ref = 'builtin(1)' },
        { ref = '%(1)', target_ref = 'builtin(1)' },
        { ref = 'builtin(1)', target_ref = 'builtin(1)' },
      },
      vim.tbl_map(function(item) return { ref = item.ref, target_ref = item.target_ref } end, items)
    )
  end)

  it('creates Man commands with modifiers', function()
    local item = { name = 'printf', section = '3' }
    local alias = { name = '!', section = '1', target_name = 'builtin', target_section = '1' }

    eq('Man 3 printf', man_nvim.make_man_command(item))
    eq('vertical Man 3 printf', man_nvim.make_man_command(item, 'vertical '))
    eq('vertical Man 1 builtin', man_nvim.make_man_command(alias, 'vertical '))
  end)

  it('parses negative filter terms from Telescope prompts', function()
    eq({
      positive_prompt = 'format output',
      negatives = { 'tcl', 'tk' },
    }, man_nvim.parse_filter_prompt('format -tcl output -tk'))

    eq({
      positive_prompt = '',
      negatives = { 'tcl' },
    }, man_nvim.parse_filter_prompt('-tcl'))
  end)

  it('filters multiple negative Telescope prompt terms', function()
    eq(true, man_nvim.matches_filter_prompt('format(1) - file formatter', 'format -tcl -tk'))
    eq(false, man_nvim.matches_filter_prompt('format(ntcl) - tcl format', 'format -tcl -tk'))
    eq(false, man_nvim.matches_filter_prompt('format(tk) - tk format', 'format -tcl -tk'))
  end)

  it('smartcases negative Telescope prompt terms', function()
    with_options({ ignorecase = true, smartcase = true }, function()
      eq(false, man_nvim.matches_filter_prompt('format(ntcl) - Tcl format', 'format -tcl'))
      eq(false, man_nvim.matches_filter_prompt('format(n) - tcl format', 'format -tcl'))
      eq(false, man_nvim.matches_filter_prompt('format(ntcl) - Tcl format', 'format -Tcl'))
      eq(true, man_nvim.matches_filter_prompt('format(n) - tcl format', 'format -Tcl'))
    end)
  end)

  it('delegates Telescope sorting with only positive prompt terms', function()
    local seen_prompt
    local sorter = man_nvim.filter_sorter({
      scoring_function = function(_, prompt)
        seen_prompt = prompt
        return 1
      end,
      highlighter = function(_, prompt) return { prompt } end,
    })

    eq(1, sorter:scoring_function('format -tcl output', 'format(1) - output'))
    eq('format output', seen_prompt)
    eq({ 'format output' }, sorter:highlighter('format -tcl output', 'format(1) - output'))
    eq(-1, sorter:scoring_function('format -tcl output', 'format(ntcl) - tcl output'))
  end)

  it('registers the Telescope extension', function()
    man_nvim.setup()
    eq(man_nvim.picker, require('telescope').extensions.man.man)
  end)
end)
