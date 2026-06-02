local man_nvim = require('man_nvim')
local telescope = require('telescope')

return telescope.register_extension({
  exports = { man = man_nvim.picker },
})
