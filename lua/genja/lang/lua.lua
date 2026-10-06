-- Lua
-- lazydev.nvim (a dependency, see README) supplies the Neovim runtime and plugin
-- libraries, so no workspace.library list is needed here.
return {
	servers = {
		lua_ls = {
			settings = {
				Lua = {
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
