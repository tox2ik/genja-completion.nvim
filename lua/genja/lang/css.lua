-- CSS / SCSS / Less
-- cssls (Mason: css-lsp, from vscode-langservers-extracted) is an npm package, so Node must be on
-- PATH. Completion, hover, colours and validation for css, scss and less; formatting with
-- vim.lsp.buf.format(). Project rules come from stylelint (lua/genja/ext/lint.lua in the config).
---@type genja.Lang
return {
	servers = {
		cssls = {},
	},
}
