-- LSP entry point (Neovim 0.11+).
--
--   lua/genja/lsp/config.lua    defaults: which languages are on, mason options
--   setup(opts)                 the same shape, merged over the defaults
--   lua/genja/lsp/local.lua     optional per-machine overrides, same shape,
--                               merged last. Lives in your Neovim config
--                               directory, not in this plugin.
--   lua/genja/lang/<name>.lua   one language each, returning:
--
--     {
--       servers = { <lspconfig name> = <vim.lsp.Config overrides>, ... },
--       tools   = { <mason package name>, ... },
--     }
--
-- Language files are found on the runtimepath, so one in your Neovim config
-- directory adds a language, or replaces the one of the same name shipped here.

local M = {}

---@class genja.Lang
---@field servers? table<string, vim.lsp.Config>
---@field tools? string[]

---config.lua, then setup() opts, then local.lua when that file exists.
---@param opts? genja.lsp.Opts
---@return genja.lsp.Opts
local function load_config(opts)
	local config = vim.tbl_deep_extend('force', require('genja.lsp.config'), opts or {})
	if #vim.api.nvim_get_runtime_file('lua/genja/lsp/local.lua', false) > 0 then
		config = vim.tbl_deep_extend('force', config, require('genja.lsp.local'))
	end
	return config
end

---@param name string
---@return genja.Lang?
local function load_lang(name)
	local file = ('lua/genja/lang/%s.lua'):format(name)
	if #vim.api.nvim_get_runtime_file(file, false) == 0 then
		vim.notify(('genja: language %q is enabled but there is no %s'):format(name, file), vim.log.levels.WARN)
		return
	end
	local ok, lang = pcall(require, 'genja.lang.' .. name)
	if ok and type(lang) == 'table' then
		return lang
	end
	vim.notify(
		('genja.lang.%s: %s'):format(name, ok and 'must return a table' or lang),
		vim.log.levels.ERROR
	)
end

---@param set table<string, true>
---@return string[]
local function sorted(set)
	local keys = vim.tbl_keys(set)
	table.sort(keys)
	return keys
end

---Install Mason packages that are not language servers.
---@param tools string[]
local function install_tools(tools)
	if #tools == 0 then
		return
	end
	local registry = require('mason-registry')
	registry.refresh(vim.schedule_wrap(function()
		for _, name in ipairs(tools) do
			local ok, pkg = pcall(registry.get_package, name)
			if not ok then
				vim.notify(('mason: unknown package %q'):format(name), vim.log.levels.WARN)
			elseif not pkg:is_installed() and not pkg:is_installing() then
				pkg:install()
			end
		end
	end))
end

---@param opts? genja.lsp.Opts
function M.setup(opts)
	M.config = load_config(opts) -- inspect with :lua =require('genja.lsp').config

	if M.config.diagnostics then
		vim.diagnostic.config(M.config.diagnostics)
	end

	-- Add nvim-cmp capabilities to every server.
	local has_cmp, cmp_lsp = pcall(require, 'cmp_nvim_lsp')
	if has_cmp then
		vim.lsp.config('*', { capabilities = cmp_lsp.default_capabilities() })
	end

	-- vim.spairs iterates in sorted order, so when two languages configure the
	-- same server their overrides always merge in the same order.
	local servers, tools = {}, {} -- sets
	for name, on in vim.spairs(M.config.enabled) do
		local lang = on and load_lang(name) or {}
		for server, overrides in pairs(lang.servers or {}) do
			vim.lsp.config(server, overrides)
			servers[server] = true
		end
		for _, tool in ipairs(lang.tools or {}) do
			tools[tool] = true
		end
	end
	servers, tools = sorted(servers), sorted(tools)

	require('mason').setup(M.config.mason)
	require('mason-lspconfig').setup({
		ensure_installed = servers,
		automatic_enable = servers, -- vim.lsp.enable() these only, once installed
	})
	install_tools(tools)
end

return M
