-- Python tools from mason (autotools-language-server, gitlint, yamllint ...) each live in a venv:
-- mason/packages/<pkg>/venv/. Its pyvenv.cfg `home =` names the Python it was built from; the
-- venv's python.exe only starts that one. When that Python is uninstalled or moved, every tool in
-- the venv exits at once (code 103 on Windows) and the server or linter just never shows up.
--
--   require('genja.lsp.venv').list()   every venv with its base Python and whether it exists
--
-- Used by :checkhealth genja.lsp (lsp/health.lua) and the config's tests/comps011. No requires:
-- the tests load it with dofile.

local M = {}

---@class genja.lsp.Venv
---@field name string mason package name
---@field cfg string path of pyvenv.cfg
---@field home string|nil `home =` from pyvenv.cfg
---@field python string|nil the base Python it expects
---@field ok boolean that Python exists

---mason's packages folder: its own setting when mason is loaded, else the default.
---@return string
function M.packages_dir()
	local ok, settings = pcall(require, 'mason.settings')
	if ok and settings.current and settings.current.install_root_dir then
		return vim.fs.joinpath(settings.current.install_root_dir, 'packages')
	end
	return vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages')
end

---The base Python a venv home should hold.
---@param home string
---@return string|nil first existing candidate, else the first one
local function base_python(home)
	local names = { 'python3', 'python' }
	if vim.fn.has('win32') == 1 then
		names = { 'python.exe' }
	end
	for _, name in ipairs(names) do
		local path = vim.fs.joinpath(home, name)
		if vim.uv.fs_stat(path) then
			return path
		end
	end
	return vim.fs.joinpath(home, names[1])
end

---Every mason package with a venv, sorted by package name.
---@return genja.lsp.Venv[]
function M.list()
	local result = {}
	local root = M.packages_dir()
	if not vim.uv.fs_stat(root) then
		return result
	end
	for pkg, kind in vim.fs.dir(root) do
		local cfg = vim.fs.joinpath(root, pkg, 'venv', 'pyvenv.cfg')
		if kind == 'directory' and vim.uv.fs_stat(cfg) then
			local home = nil
			-- the first `home =` wins: that is the one the venv's launcher uses
			for _, line in ipairs(vim.fn.readfile(cfg)) do
				local value = line:match('^%s*home%s*=%s*(.-)%s*$')
				if value and not home then
					home = value
				end
			end
			local venv = { name = pkg, cfg = cfg, home = home, ok = false }
			if home then
				venv.python = base_python(home)
				venv.ok = vim.uv.fs_stat(venv.python) ~= nil
			end
			table.insert(result, venv)
		end
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

---What to do about a broken venv.
---@param venv genja.lsp.Venv
---@return string
function M.fix(venv)
	return ':MasonInstall --force ' .. venv.name
end

return M
