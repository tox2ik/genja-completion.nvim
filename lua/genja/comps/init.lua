-- genja: language servers and completion for Neovim 0.11+.
--
--   require('genja').setup({
--     lsp = { enabled = { php = true } },   -- see lua/genja/lsp/config.lua
--     completion = { features = { ... } },  -- see lua/genja/completion/init.lua
--   })
--
-- Both keys are optional. Set one to false to skip that half.

local M = {}

---@class genja.Opts
---@field lsp? genja.lsp.Opts|false
---@field completion? genja.completion.Opts|false

---@param opts? genja.Opts
function M.setup(opts)
	opts = opts or {}
	if vim.fn.has('nvim-0.11') == 0 then
		vim.notify('genja needs Neovim 0.11 or newer', vim.log.levels.ERROR)
		return
	end
	-- Completion first, so its sources are registered before servers attach.
	if opts.completion ~= false then
		require('genja.completion').setup(opts.completion)
	end
	if opts.lsp ~= false then
		require('genja.lsp').setup(opts.lsp)
	end
end

return M
