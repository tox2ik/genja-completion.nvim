-- JSON / JSONC
-- jsonls (Mason: json-lsp) is an npm package, so Node must be on PATH.
-- It reports syntax errors itself (missing or trailing commas, unclosed
-- brackets, duplicate keys), so no separate linter is needed. In jsonc files
-- comments and trailing commas are allowed, as in tsconfig.json.
-- Schemas: a file's own "$schema" property is fetched and validated against.
-- Formatting: vim.lsp.buf.format() (provideFormatter, set by nvim-lspconfig).
---@type genja.Lang
return {
	servers = {
		jsonls = {
			settings = {
				json = {
					validate = { enable = true },
				},
			},
		},
	},
}
