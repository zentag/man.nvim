local lazypath = vim.fs.joinpath(vim.fn.stdpath('data'), 'lazy', 'lazy.nvim')
if vim.uv.fs_stat(lazypath) then
  vim.opt.rtp:prepend(lazypath)
else
  vim.env.LAZY_STDPATH = '.tests'
  local body, request_err
  vim.net.request(
    'https://raw.githubusercontent.com/folke/lazy.nvim/main/bootstrap.lua',
    {},
    function(err, response)
      request_err = err
      body = response and response.body or nil
    end
  )
  if not vim.wait(30000, function()
    return body ~= nil or request_err ~= nil
  end) then
    error('Timed out bootstrapping lazy.nvim')
  end
  if request_err then
    error(request_err)
  end
  local bootstrap, load_err = load(body)
  if not bootstrap then
    error(load_err)
  end
  bootstrap()
  vim.opt.rtp:prepend('.tests')
end

require('lazy.minit').setup({
  headless = { process = false, log = false },
  spec = {
    { 'echasnovski/mini.pick', opts = {} },
    { 'nvim-lua/plenary.nvim' },
  },
})
