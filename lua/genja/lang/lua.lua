-- Lua
-- lazydev.nvim (a dependency, see README) supplies the Neovim runtime and the
-- library of every plugin a file require()s, and keeps the entries listed here.
-- Types used without a require need their library listed in workspace.library:
-- lazy.nvim's LazyPluginSpec / LazySpec in plugin spec files.
local lazy_lib = vim.fs.normalize(vim.fs.joinpath(vim.fn.stdpath('data'), 'lazy', 'lazy.nvim', 'lua'))

---@type genja.Lang
return {
	servers = {
		lua_ls = {
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
			settings = {
				Lua = {
					-- like gopls usePlaceholders: function completions insert name(arg1, arg2)
					-- as a snippet, cursor on the first argument. 'Both': offer both forms.
					completion = { callSnippet = 'Replace' },
					workspace = {
						checkThirdParty = false,
						library = { lazy_lib },
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
