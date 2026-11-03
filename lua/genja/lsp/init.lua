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
--       note    = <one line, for a language without a server>,
--     }
--
-- Language files are found on the runtimepath, so one in your Neovim config
-- directory adds a language, or replaces the one of the same name shipped here.

local SRC = 'lsp/init.lua: '

local M = {}

---@class genja.Lang
---@field servers? table<string, vim.lsp.Config>
---@field tools? string[]
---@field note? string one line on what the language does without a server; shown by the config's `make status`

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
		vim.notify((SRC .. 'language %q is enabled but there is no %s'):format(name, file), vim.log.levels.WARN)
		return
	end
	local ok, lang = pcall(require, 'genja.lang.' .. name)
	if ok and type(lang) == 'table' then
		return lang
	end
	vim.notify(
		(SRC .. 'genja.lang.%s: %s'):format(name, (ok and 'must return a table' or lang)),
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
				vim.notify((SRC .. 'mason: unknown package %q'):format(name), vim.log.levels.WARN)
			elseif not pkg:is_installed() and not pkg:is_installing() then
				pkg:install()
			end
		end
	end))
end

-- filetype -> mason package (and its server) whose cut-off install is repaired when such a file opens
---@type table<string, { package: string, server: string }>
local REPAIR_ON_OPEN = {
    lua = { package = 'lua-language-server', server = 'lua_ls' },
}
local repair_tried = {} ---@type table<string, true> once per session, so a failing repair doesn't loop

---Silently reinstall a package whose folder has no receipt (lsp/receipt.lua), then attach its
---server to the open buffers. mason's own install, so the launcher, schema links and receipt get
---written; moving mason/staging into place would leave those out. Only a failure is reported:
---it fails again while another nvim still runs the old server.
---@param item { package: string, server: string }
local function repair(item)
    local name = item.package
    local broken = require('genja.lsp.receipt').check(name)
    if not broken or repair_tried[name] then
        return
    end
    repair_tried[name] = true
    local ok, pkg = pcall(require('mason-registry').get_package, name)
    if not ok or pkg:is_installing() then
        return
    end
    pkg:install({ force = true }, vim.schedule_wrap(function(success)
        if success then
            -- enable() runs FileType again for open buffers, so they attach without :e
            vim.lsp.enable(item.server)
        else
            local fix = require('genja.lsp.receipt').fix(broken)
            vim.notify((SRC .. '%s: install was cut off and the reinstall failed (old files still in use?); fix: %s')
                :format(name, fix), vim.log.levels.ERROR)
        end
    end))
end

---Servers and tools of every enabled language.
---@param config genja.lsp.Opts
---@param apply? boolean call vim.lsp.config() for each server
---@return string[] servers lspconfig names
---@return string[] tools mason package names
local function collect(config, apply)
	-- vim.spairs iterates in sorted order, so when two languages configure the
	-- same server their overrides always merge in the same order.
	local servers, tools = {}, {} -- sets
	for name, on in vim.spairs(config.enabled) do
		local lang = (on and load_lang(name) or {})
		for server, overrides in pairs(lang.servers or {}) do
			if apply then
				vim.lsp.config(server, overrides)
			end
			servers[server] = true
		end
		for _, tool in ipairs(lang.tools or {}) do
			tools[tool] = true
		end
	end
	return sorted(servers), sorted(tools)
end

---Everything the enabled languages want from Mason: servers (lspconfig names)
---then tools (package names). For mason-tool-installer, which runs headless
---(lua/lazyp/comps/mason-tool-installer.lua).
---@return string[]
function M.packages()
	local servers, tools = collect(M.get())
	return vim.list_extend(servers, tools)
end

---@class genja.lsp.Language
---@field name string key in `enabled`
---@field on boolean
---@field servers string[] lspconfig names
---@field tools string[] mason package names
---@field note? string from the language file

---Every language in `enabled`, on or off, with what it brings. For the config's `make status`.
---@return genja.lsp.Language[]
function M.languages()
	local result = {}
	for name, on in vim.spairs(M.get().enabled or {}) do
		local lang = load_lang(name) or {}
		local servers = vim.tbl_keys(lang.servers or {})
		table.sort(servers)
		table.insert(result, { name = name, on = on == true, servers = servers, tools = lang.tools or {}, note = lang.note })
	end
	return result
end

---Servers (lspconfig names) the enabled languages want, installed or not.
---For lsp/installed.lua: mason-lspconfig enables a server only once it is installed.
---@return string[]
function M.servers()
	return (collect(M.get())) -- first result only
end

---@param opts? genja.lsp.Opts
function M.setup(opts)
	M.config = load_config(opts) -- inspect with :lua =require('genja.lsp').config

	if M.config.diagnostics then
		vim.diagnostic.config(M.config.diagnostics)
	end

	-- blink.cmp's completion capabilities for every server (blink sets them on 0.11 too;
	-- explicit here, so the order of the two setups doesn't matter)
	local has_blink, blink = pcall(require, 'blink.cmp')
	if has_blink then
		vim.lsp.config('*', { capabilities = blink.get_lsp_capabilities() })
	end

	local servers, tools = collect(M.config, true)

	-- g:genja_lsp_no_install: enable what's there, install nothing (test runs start and kill
	-- many nvims; an install cut off halfway leaves mason/staging behind)
	local install = (vim.g.genja_lsp_no_install ~= true)
	local ensure = (install and servers or {})

	require('mason').setup(M.config.mason)
	require('mason-lspconfig').setup({
		ensure_installed = ensure,
		automatic_enable = servers, -- vim.lsp.enable() these only, once installed
	})
	if install then
		install_tools(tools)
		vim.api.nvim_create_autocmd('FileType', {
			group = vim.api.nvim_create_augroup('genja.lsp.repair', { clear = true }),
			pattern = vim.tbl_keys(REPAIR_ON_OPEN),
			desc = 'mason: reinstall a server whose install was cut off',
			callback = function(args)
				repair(REPAIR_ON_OPEN[args.match])
			end,
		})
		-- setup() may run after the first file's FileType (VeryLazy)
		if REPAIR_ON_OPEN[vim.bo.filetype] then
			repair(REPAIR_ON_OPEN[vim.bo.filetype])
		end
	end

	-- :EnableLang [-on|-off] [-save] <lang>
	vim.api.nvim_create_user_command('EnableLang', function(cmd)
		local on, save, name = true, false, nil
		for _, arg in ipairs(cmd.fargs) do
			if arg == '-on' then
				on = true
			elseif arg == '-off' then
				on = false
			elseif arg == '-save' then
				save = true
			elseif name == nil then
				name = arg
			else
				vim.notify(SRC .. 'usage: :EnableLang [-on|-off] [-save] <lang>', vim.log.levels.ERROR)
				return
			end
		end
		if not name then
			vim.notify(SRC .. 'usage: :EnableLang [-on|-off] [-save] <lang>', vim.log.levels.ERROR)
			return
		end
		M.set_lang(name, on, save)
	end, {
		nargs = '+',
		desc = 'Turn a language from lua/genja/lang/ on or off; -save saves it in local.lua',
		complete = function(lead, line)
			local has_off = (line:find('%s%-off%f[%s%z]') ~= nil)
			local has_on = (line:find('%s%-on%f[%s%z]') ~= nil)
			if lead:sub(1, 1) == '-' then
				-- -on and -off exclude each other; each flag once
				local flags = {}
				if not has_on and not has_off then
					vim.list_extend(flags, { '-on', '-off' })
				end
				if not line:find('%s%-save%f[%s%z]') then
					table.insert(flags, '-save')
				end
				return vim.tbl_filter(function(flag)
					return vim.startswith(flag, lead)
				end, flags)
			end
			if has_off then
				return M.enabled_langs()
			end
			return M.disabled_langs()
		end,
	})
end

---Languages listed in `enabled` that are on.
---@return string[]
function M.enabled_langs()
	local names = {}
	for name, on in vim.spairs(M.get().enabled or {}) do
		if on then
			table.insert(names, name)
		end
	end
	return names
end

---Languages listed in `enabled` that are off.
---@return string[]
function M.disabled_langs()
	local names = {}
	for name, on in vim.spairs(M.get().enabled or {}) do
		if not on then
			table.insert(names, name)
		end
	end
	return names
end

---The off language that would handle a filetype: one of its servers lists the
---filetype, or it has no server and is named after it (make, gitconfig).
---@param ft string
---@return string?
function M.disabled_lang_for(ft)
	if ft == '' then
		return
	end
	for _, name in ipairs(M.disabled_langs()) do
		local lang = load_lang(name) or {}
		if not lang.servers and name == ft then
			return name
		end
		for server in pairs(lang.servers or {}) do
			-- an off language's overrides were never applied: check them and lspconfig's defaults
			local override = lang.servers[server].filetypes or {}
			local default = (vim.lsp.config[server] or {}).filetypes or {}
			if vim.tbl_contains(override, ft) or vim.tbl_contains(default, ft) then
				return name
			end
		end
	end
end

---Turn a language on for this session: configure and enable its servers
---(they attach to open buffers too) and install its tools.
---@param lang genja.Lang
---@return string[] servers
local function start_lang(lang)
	local servers = {}
	for server, overrides in pairs(lang.servers or {}) do
		vim.lsp.config(server, overrides)
		table.insert(servers, server)
	end
	table.sort(servers)
	-- mason-lspconfig's automatic_enable list is fixed at setup(), so enable here;
	-- a server that isn't installed yet is installed too
	local install = (vim.g.genja_lsp_no_install ~= true)
	for _, server in ipairs(servers) do
		local cmd = (vim.lsp.config[server] or {}).cmd
		local exe = (type(cmd) == 'table' and cmd[1] or nil)
		if exe and vim.fn.executable(exe) == 0 and install then
			-- mason-lspconfig; open buffers attach after :e once it is installed
			vim.cmd('LspInstall ' .. server)
		end
		vim.lsp.enable(server)
	end
	if install then
		install_tools(lang.tools or {})
	end
	return servers
end

---Turn a language off for this session: disable its servers and stop their clients,
---unless another language that is still on wants the same server. Tools stay installed.
---@param lang genja.Lang
---@return string[] servers
local function stop_lang(lang)
	local still_wanted = {}
	for _, server in ipairs(M.servers()) do -- M.config.enabled is already updated
		still_wanted[server] = true
	end
	local servers = {}
	for server in pairs(lang.servers or {}) do
		if not still_wanted[server] then
			vim.lsp.enable(server, false)
			for _, client in ipairs(vim.lsp.get_clients({ name = server })) do
				client:stop()
			end
			table.insert(servers, server)
		end
	end
	table.sort(servers)
	return servers
end

---Path of local.lua: the one on the runtimepath, else a new one in the config.
---@return string
local function local_path()
	local found = vim.api.nvim_get_runtime_file('lua/genja/lsp/local.lua', false)[1]
	if found then
		return found
	end
	return vim.fn.stdpath('config') .. '/lua/genja/lsp/local.lua'
end

---Text of local.lua with `enabled.<name>` set, comments kept. Edits the
---`enabled = { ... }` table in place (no nested braces inside it), or adds one.
---@param text string
---@param name string
---@param on boolean
---@return string? text nil when the file has no `return {` to add to
local function set_in_text(text, name, on)
	local value = tostring(on)
	local start, open_end = text:find('enabled%s*=%s*{')
	if start then
		local close = text:find('}', open_end, true)
		if not close then
			return
		end
		local inner = text:sub(open_end + 1, close - 1)
		local key = '%f[%w_]' .. vim.pesc(name) .. '%s*=%s*'
		local new_inner, count = inner:gsub(key .. '%a+', name .. ' = ' .. value, 1)
		if count == 0 then
			new_inner = ' ' .. name .. ' = ' .. value .. ',' .. inner
		end
		return text:sub(1, open_end) .. new_inner .. text:sub(close)
	end
	local _, ret_end = text:find('return%s*{')
	if not ret_end then
		return
	end
	return text:sub(1, ret_end) .. ('\n\tenabled = { %s = %s },'):format(name, value) .. text:sub(ret_end + 1)
end

---Save `enabled.<name> = on` in local.lua. The edited text is loaded again
---before writing; if it doesn't give that value, nothing is written.
---@param name string
---@param on boolean
---@return boolean saved
local function save_lang(name, on)
	local path = local_path()
	local text = table.concat({
		'-- Per-machine overrides for genja LSP settings, merged over setup() opts.',
		'---@type genja.lsp.Opts',
		'return {',
		'}',
		'',
	}, '\n')
	if vim.uv.fs_stat(path) then
		text = table.concat(vim.fn.readfile(path), '\n') .. '\n'
	end
	local new = set_in_text(text, name, on)
	local chunk = (new and load(new, '=local.lua') or nil)
	local ok, result = false, nil
	if chunk then
		ok, result = pcall(chunk)
	end
	if not ok or type(result) ~= 'table' or (result.enabled or {})[name] ~= on then
		vim.notify((SRC .. 'could not set %s in %s; edit it by hand'):format(name, path), vim.log.levels.ERROR)
		return false
	end
	vim.fn.mkdir(vim.fs.dirname(path), 'p')
	-- text ends in '\n'; drop the empty last item so writefile doesn't add a blank line
	local lines = vim.split(new, '\n', { plain = true })
	if lines[#lines] == '' then
		table.remove(lines)
	end
	vim.fn.writefile(lines, path)
	package.loaded['genja.lsp.local'] = nil -- get() before setup() reads it again
	return true
end

---Turn a language on or off for this session; with save, also write it in local.lua.
---Make, gitconfig and sshconfig diagnostics follow in buffers opened afterwards (or after :e).
---@param name string key in `enabled`, e.g. 'php'
---@param on boolean
---@param save? boolean
function M.set_lang(name, on, save)
	if not M.config then
		vim.notify(SRC .. 'setup() has not run yet', vim.log.levels.ERROR)
		return
	end
	local lang = load_lang(name)
	if not lang then
		return
	end
	local state = (on and 'on' or 'off')
	local msg
	if (M.config.enabled[name] == true) == on then
		msg = ('%s is already %s'):format(name, state)
	else
		M.config.enabled[name] = on
		local servers
		if on then
			servers = start_lang(lang)
		else
			servers = stop_lang(lang)
		end
		msg = ('%s %s for this session: %s'):format(name, state, (#servers > 0 and table.concat(servers, ', ') or 'no server'))
	end
	if save and save_lang(name, on) then
		msg = msg .. '; saved in local.lua'
	end
	vim.notify(SRC .. msg)
end

---@param name string key in `enabled`, e.g. 'php'
function M.enable_lang(name)
	M.set_lang(name, true)
end

---The settings in effect: what setup() resolved, or before setup() the defaults
---merged with local.lua (setup() opts are not known yet then).
---Other config reads these, e.g. require('genja.lsp').get().mason
---@return genja.lsp.Opts
function M.get()
	return M.config or load_config()
end

---Is a language turned on? Same merge as setup(), so local.lua counts.
---@param name string key in `enabled`, e.g. 'php'
---@return boolean
function M.enabled(name)
	return (M.get().enabled or {})[name] == true
end

return M
