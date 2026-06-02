local assert = require('luassert')
local man_nvim = require('man_nvim')

local eq = assert.are.same
local isnil = assert.is.Nil

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

  it('registers the Telescope extension', function()
    man_nvim.setup()
    eq(man_nvim.picker, require('telescope').extensions.man.man)
  end)
end)
