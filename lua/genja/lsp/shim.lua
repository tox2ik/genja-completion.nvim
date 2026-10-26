-- mason puts a launcher for every tool in mason/bin (that folder goes on PATH). On Windows it is a
-- .cmd file that runs "%dp0%\..\packages\<pkg>\<file>"; elsewhere a symlink. A launcher whose
-- target is gone (interrupted uninstall or update) still counts as executable, so the server or
-- linter only fails when started.
--
--   require('genja.lsp.shim').list()   every launcher with its target and whether it exists
--
-- Used by :checkhealth genja.lsp (lsp/health.lua) and the config's tests/comps011. No requires:
-- the tests load it with dofile.

local M = {}

---@class genja.lsp.Shim
---@field name string launcher file name, e.g. gopls.cmd
---@field path string the launcher
---@field target string|nil what it starts; nil: no target found in a .cmd
---@field ok boolean the target exists
---@field absolute boolean|nil a .cmd naming its target by full path (older mason): breaks if the mason folder moves

---mason's bin folder: its own setting when mason is loaded, else the default.
---@return string
function M.bin_dir()
	local ok, settings = pcall(require, 'mason.settings')
	if ok and settings.current and settings.current.install_root_dir then
		return vim.fs.joinpath(settings.current.install_root_dir, 'bin')
	end
	return vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'bin')
end

---The path a .cmd launcher starts, resolved against the bin folder.
---@param path string
---@param bin string
---@return string|nil target
---@return boolean absolute
local function cmd_target(path, bin)
	for _, line in ipairs(vim.fn.readfile(path)) do
		-- %dp0% is the launcher's own folder: "%dp0%\..\packages\..."
		local rel = line:match('"%%dp0%%\\(.-)"')
		if rel then
			return vim.fs.normalize(vim.fs.joinpath(bin, rel)), false
		end
		-- older mason wrote "C:\...\mason\packages\..." instead
		local abs = line:match('"(%a:\\.-)"')
		if abs then
			return vim.fs.normalize(abs), true
		end
	end
	return nil, false
end

---Every launcher in mason/bin, sorted by name.
---@return genja.lsp.Shim[]
function M.list()
	local result = {}
	local bin = M.bin_dir()
	if not vim.uv.fs_stat(bin) then
		return result
	end
	for name, kind in vim.fs.dir(bin) do
		local path = vim.fs.joinpath(bin, name)
		local shim = { name = name, path = path, ok = false }
		if kind == 'link' then
			shim.target = vim.uv.fs_readlink(path)
			-- fs_stat follows the link: nil when the target is gone
			shim.ok = vim.uv.fs_stat(path) ~= nil
		elseif name:lower():match('%.cmd$') then
			shim.target, shim.absolute = cmd_target(path, bin)
			if shim.target then
				shim.ok = vim.uv.fs_stat(shim.target) ~= nil
			end
		else
			-- a plain file: it is its own target
			shim.target = path
			shim.ok = true
		end
		table.insert(result, shim)
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

---What to do about a broken launcher.
---@param shim genja.lsp.Shim
---@return string
function M.fix(shim)
	local pkg = shim.target and shim.target:match('/packages/([^/]+)/')
	if pkg then
		return ':MasonInstall --force ' .. pkg
	end
	return 'delete ' .. shim.path .. ', or reinstall its package from :Mason'
end

return M
