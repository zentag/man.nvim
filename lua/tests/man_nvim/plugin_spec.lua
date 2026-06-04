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

  it('parses negative filter terms from picker queries', function()
    eq(
      {
        positive_query = { 'p', 'r', 'i', 'n', 't', 'f' },
        negatives = { 'tcl' },
      },
      man_nvim.parse_filter_query({
        'p',
        'r',
        'i',
        'n',
        't',
        'f',
        ' ',
        '-',
        't',
        'c',
        'l',
      })
    )

    eq({
      positive_query = {},
      negatives = { 'tcl', 'tk' },
    }, man_nvim.parse_filter_query({ '-', 't', 'c', 'l', ' ', '-', 't', 'k' }))
  end)

  it('filters negative picker query terms before matching', function()
    local stritems = {
      '[1 User commands] printf(1) - formatted output',
      '[n Miscellaneous] format(ntcl) - Format a string in the style of sprintf',
      '[3 Library calls] tcl_createinterp(3) - create tcl interpreter',
    }
    local inds = { 1, 2, 3 }

    eq({ 1 }, man_nvim.match(stritems, inds, vim.fn.split('-tcl', [[\zs]])))
    eq({ 1 }, man_nvim.match(stritems, inds, vim.fn.split('format output -tcl', [[\zs]])))
  end)

  it('filters multiple negative picker query terms', function()
    local stritems = {
      'printf - output',
      'format(ntcl) - tcl format',
      'format(tk) - tk format',
      'format(1) - file formatter',
    }

    eq({ 4 }, man_nvim.match(stritems, { 1, 2, 3, 4 }, vim.fn.split('format -tcl -tk', [[\zs]])))
  end)

  it('smartcases negative picker query terms', function()
    with_options({ ignorecase = true, smartcase = true }, function()
      local stritems = {
        'Format(1) - file formatter',
        'format(ntcl) - Tcl format',
        'format(n) - tcl format',
      }

      eq({ 1 }, man_nvim.match(stritems, { 1, 2, 3 }, vim.fn.split('format -tcl', [[\zs]])))
      eq({ 1, 3 }, man_nvim.match(stritems, { 1, 2, 3 }, vim.fn.split('format -Tcl', [[\zs]])))
    end)
  end)

  it('matches negative picker queries against all items', function()
    local stritems = {
      'printf - output',
      'format(ntcl) - Tcl format',
      'format(1) - file formatter',
    }

    eq({ 3 }, man_nvim.match(stritems, { 2 }, vim.fn.split('format -tcl', [[\zs]])))
  end)

  it('registers the mini.pick picker', function()
    man_nvim.setup()
    eq(man_nvim.picker, require('mini.pick').registry.man)
  end)
end)
