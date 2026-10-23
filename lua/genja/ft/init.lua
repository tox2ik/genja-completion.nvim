-- Filetype detection, one file per filetype in this directory:
--
--   -- lua/genja/ft/gitignore.lua
--   return { filename = { ['.ignore'] = 'gitignore' } }
--
-- Each file returns a spec for vim.filetype.add() (extension, filename,
-- pattern). A value can also be a function(path, bufnr) returning a filetype.
-- Files are found on the runtimepath, so lua/genja/ft/<name>.lua in your
-- Neovim config directory adds a filetype, or replaces the one shipped here.

local SRC = 'ft/init.lua: '

local M = {}

function M.setup()
	local seen = {}
	-- Runtimepath order: your config directory comes before this plugin.
	for _, path in ipairs(vim.api.nvim_get_runtime_file('lua/genja/ft/*.lua', true)) do
		local name = vim.fn.fnamemodify(path, ':t:r')
		if name ~= 'init' and not seen[name] then
			seen[name] = true
			local ok, spec = pcall(dofile, path)
			if ok and type(spec) == 'table' then
				vim.filetype.add(spec)
			else
				vim.notify((SRC .. 'genja.ft.%s: %s'):format(name, ok and 'must return a table' or spec), vim.log.levels.ERROR)
			end
		end
	end
end

return M
