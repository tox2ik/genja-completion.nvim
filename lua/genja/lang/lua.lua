-- Lua
-- lazydev.nvim (a dependency, see README) supplies the Neovim runtime and the
-- library of every plugin a file require()s, and keeps the entries listed here.
-- Types used without a require need their library listed in workspace.library:
-- lazy.nvim's LazyPluginSpec / LazySpec in plugin spec files.
--
-- Until lua_ls has loaded the workspace it flags vim, require and other
-- well-known globals as undefined (slow PCs). A buffer's diagnostics stay hidden
-- until lua_ls reports its first progress 'end', or SHOW_AFTER ms at most.
--
-- env GENJA_LUA_NO_LIB=1 (set by the config's tests/Makefile): no workspace.library
-- here and lazydev off (lua/lazyp/langs-comps/lazydev.lua), so lua_ls answers
-- without indexing the Neovim runtime first.
local lazy_lib = vim.fs.normalize(
    vim.fs.joinpath(
        vim.fn.stdpath('data'), 'lazy', 'lazy.nvim', 'lua'))

local library = { lazy_lib }
if vim.env.GENJA_LUA_NO_LIB ~= nil and vim.env.GENJA_LUA_NO_LIB ~= '' then
	library = {}
end

local SHOW_AFTER = 10000 -- ms; fallback when no progress 'end' arrives

local ready = {} ---@type table<integer, true> lua_ls clients done loading
local hidden = {} ---@type table<integer, integer[]> buffers hidden per client

---Show the diagnostics hidden while lua_ls was loading.
---@param client_id integer
local function show_diagnostics(client_id)
	if ready[client_id] then
		return
	end
	ready[client_id] = true
	for _, buf in ipairs(hidden[client_id] or {}) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.diagnostic.enable(true, { bufnr = buf })
		end
	end
	hidden[client_id] = nil
	pcall(vim.api.nvim_del_augroup_by_name, 'genja.lua_ls.ready.' .. client_id)
end

---Hide a buffer's diagnostics until lua_ls is ready.
---@param client vim.lsp.Client
---@param bufnr integer
local function hide_until_ready(client, bufnr)
	if ready[client.id] then
		return
	end
	vim.diagnostic.enable(false, { bufnr = bufnr })
	if hidden[client.id] then
		table.insert(hidden[client.id], bufnr)
		return -- the client's autocmd and timer are already set
	end
	hidden[client.id] = { bufnr }
	vim.api.nvim_create_autocmd('LspProgress', {
		group = vim.api.nvim_create_augroup('genja.lua_ls.ready.' .. client.id, { clear = true }),
		pattern = 'end',
		desc = 'lua_ls: show diagnostics once the workspace is loaded',
		callback = function(args)
			if args.data.client_id == client.id then
				show_diagnostics(client.id)
			end
		end,
	})
	vim.defer_fn(function()
		show_diagnostics(client.id)
	end, SHOW_AFTER)
end

---@type genja.Lang
return {
	servers = {

		lua_ls = {
			-- lua_ls logs into its own install folder by default; an open log there keeps mason
			-- from deleting that folder on Windows and cuts the next update off (lsp/receipt.lua)
			cmd = { 'lua-language-server', '--logpath=' .. vim.fs.joinpath(vim.fn.stdpath('log'), 'lua_ls') },

			-- Same markers as nvim-lspconfig, but a root at the home folder (a stray
			-- .git or .luarc.json in C:\Users\<me>) is dropped: lua_ls then runs in
			-- single-file mode instead of scanning the whole profile.

			root_dir = function(bufnr, on_dir)
				local root = vim.fs.root(bufnr, {
					'.luarc.json', '.luarc.jsonc', '.emmyrc.json', '.luacheckrc',
					'.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml', '.git',
				})

				local norm = function(p) return vim.fs.normalize(p):lower() end
				if root and norm(root) == norm(vim.uv.os_homedir()) then
					root = nil
				end
				on_dir(root)
			end,

			on_attach = function(client, bufnr)
				hide_until_ready(client, bufnr)
			end,

			settings = {
				Lua = {

					-- like gopls usePlaceholders: function completions insert name(arg1, arg2)
					-- as a snippet, cursor on the first argument. 'Both': offer both forms.
					completion = { callSnippet = 'Replace' },

					workspace = {
						checkThirdParty = false,
						library = library,
						maxPreload = 2000, -- files; safety net if a root is still too big
						preloadFileSize = 500, -- KB
					},

					diagnostics = {
						disable = { 'lowercase-global' },
						globals = {
							'require', -- lua_ls can flag require while it is still loading its builtins ??

							'IsDir',
						},
					},

				},
			},
		},
	},
}
