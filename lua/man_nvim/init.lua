local M = { apropos_cmd = { 'apropos', '.' } }

local section_names = {
  ['1'] = 'User commands',
  ['2'] = 'System calls',
  ['3'] = 'Library calls',
  ['4'] = 'Devices',
  ['5'] = 'File formats',
  ['6'] = 'Games',
  ['7'] = 'Miscellaneous',
  ['8'] = 'Admin commands',
  ['9'] = 'Kernel',
}

local default_man_modifier = 'vertical '
local function trim(s) return vim.trim(s or '') end

local function set_buffer_lines(bufnr, lines)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end

  vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
end

local function section_sort_key(section)
  return tonumber((section or ''):match('^(%d+)')) or 1000, section or ''
end

local function command_args(item)
  return { item.target_section or item.section, item.target_name or item.name }
end

M.section_label = function(section)
  local name = section_names[(section or ''):match('^(%d+)')]
  return name and ('%s %s'):format(section, name) or section or ''
end

M.parse_line = function(line)
  local names, description = (line or ''):match('^%s*(.-)%s+%-%s+(.*)$')
  if not names or names == '' then return end

  local aliases = vim.iter(vim.split(names, ',', { plain = true })):fold({}, function(acc, raw)
    local name, section = trim(raw):match('^(.+)%(([^()]+)%)$')
    name, section = trim(name), trim(section)
    if name ~= '' and section ~= '' then
      acc[#acc + 1] = { name = name, section = section, ref = ('%s(%s)'):format(name, section) }
    end
    return acc
  end)

  if #aliases == 0 then return end
  return { aliases = aliases, description = trim(description), primary = aliases[1] }
end

M.make_items = function(lines)
  local items, seen = {}, {}

  vim.iter(lines or {}):each(function(line)
    local parsed = M.parse_line(line)
    if not parsed then return end

    local alias_text = vim
      .iter(parsed.aliases)
      :fold(setmetatable({}, { __index = table }), function(acc, alias)
        acc:insert(alias.ref)
        return acc
      end)
      :concat(', ')

    vim.iter(parsed.aliases):each(function(alias)
      local key = alias.section .. '\0' .. alias.name
      if seen[key] then return end

      seen[key] = true
      local target = parsed.primary or alias
      items[#items + 1] = {
        text = ('[%s] %s - %s'):format(
          M.section_label(alias.section),
          alias.ref,
          parsed.description
        ),
        name = alias.name,
        section = alias.section,
        ref = alias.ref,
        target_name = target.name,
        target_section = target.section,
        target_ref = target.ref,
        description = parsed.description,
        aliases = alias_text,
      }
    end)
  end)

  table.sort(items, function(left, right)
    local left_number, left_section = section_sort_key(left.section)
    local right_number, right_section = section_sort_key(right.section)
    if left_number ~= right_number then return left_number < right_number end
    if left_section ~= right_section then return left_section < right_section end
    return left.name < right.name
  end)

  return items
end

M.make_man_command = function(item, modifier)
  if not item then return end

  local args = vim.iter(command_args(item)):map(vim.fn.fnameescape):totable()
  return ('%sMan %s'):format(modifier or '', table.concat(args, ' '))
end

M.open_man = function(item, modifier)
  local command = M.make_man_command(item, modifier)
  if not command then return end

  local pick = require('mini.pick')
  local state = pick.get_picker_state()
  local target = state and state.windows and state.windows.target

  vim.schedule(function()
    local man_window
    local open = function()
      vim.cmd(command)
      man_window = vim.api.nvim_get_current_win()
    end

    if target and vim.api.nvim_win_is_valid(target) then
      vim.api.nvim_win_call(target, open)
    else
      open()
    end

    if man_window and vim.api.nvim_win_is_valid(man_window) then
      vim.api.nvim_set_current_win(man_window)
    end
  end)
end

M.get_apropos = function(on_response, command)
  if not vim.system then error('man.nvim requires Neovim with vim.system()') end
  on_response = on_response or function() end

  return vim.system(
    command or M.apropos_cmd,
    { text = true },
    vim.schedule_wrap(function(result)
      local stdout = result.stdout or ''
      if result.code ~= 0 and stdout == '' then
        on_response(trim(result.stderr), '')
        return
      end

      on_response(nil, stdout)
    end)
  )
end

M.preview = function(bufnr, item)
  if not item then return end

  local args = command_args(item)
  local open_section, open_name = args[1], args[2]
  local lines = setmetatable({
    item.ref,
    '',
    item.description,
    '',
    'Section: ' .. M.section_label(item.section),
    'Aliases: ' .. item.aliases,
  }, { __index = table })

  if item.target_ref and item.target_ref ~= item.ref then
    lines:insert('Opens: ' .. item.target_ref)
    lines:insert('')
  end

  lines:insert('Open commands:')
  lines:insert('  <CR>  :vertical Man ' .. open_section .. ' ' .. open_name)
  lines:insert('  <C-x> :Man ' .. open_section .. ' ' .. open_name)
  lines:insert('  <C-v> :vertical Man ' .. open_section .. ' ' .. open_name)
  lines:insert('  <C-t> :tab Man ' .. open_section .. ' ' .. open_name)
  set_buffer_lines(bufnr, lines)
end

M.picker = function(local_opts, opts)
  local_opts, opts = local_opts or {}, vim.deepcopy(opts or {})

  local pick = require('mini.pick')
  local choose = function(item, modifier)
    if item then M.open_man(item, modifier or default_man_modifier) end
  end
  local map_open = function(char, modifier)
    return {
      char = char,
      func = function()
        choose(pick.get_picker_matches().current, modifier)
        return true
      end,
    }
  end

  opts = vim.tbl_deep_extend('force', {
    mappings = {
      choose_in_split = '',
      choose_in_tabpage = '',
      choose_in_vsplit = '',
      mark = '<M-x>',
      open_in_split = map_open('<C-x>', ''),
      open_in_tabpage = map_open('<C-t>', 'tab '),
      open_in_vsplit = map_open('<C-v>', 'vertical '),
    },
    source = {
      name = 'Man pages',
      items = function()
        M.get_apropos(function(err, body)
          if err then
            vim.notify('Failed to load man apropos database: ' .. err, vim.log.levels.ERROR)
            if pick.is_picker_active() then pick.set_picker_items({}) end
            return
          end

          local lines = vim.split(body, '\n', { plain = true, trimempty = true })
          if pick.is_picker_active() then pick.set_picker_items(M.make_items(lines)) end
        end, local_opts.apropos_cmd)
      end,
      preview = M.preview,
      choose = choose,
    },
  }, opts)

  return pick.start(opts)
end

M.setup = function() require('mini.pick').registry.man = M.picker end

return M
