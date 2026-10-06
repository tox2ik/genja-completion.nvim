-- JavaScript / TypeScript
-- tsc:    the language server built into TypeScript 7 (native compiler). It
--         replaces ts_ls and tsgo. A project pinned to TypeScript < 7 still
--         works: the mason-installed tsc is used instead of node_modules/.bin.
-- eslint: starts only in projects that have an eslint config.

-- :checkhealth vim.lsp
-- :echo executable('tsc')
-- :!tsc --version

return {
	servers = {
		tsc = {},
		eslint = {},
	},
}
