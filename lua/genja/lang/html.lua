-- HTML
-- html (Mason: html-lsp, from vscode-langservers-extracted) is an npm package, so Node must be on
-- PATH. Tags, attributes, embedded CSS and JS, formatting with vim.lsp.buf.format(). It attaches to
-- filetype html only; PHP and Twig templates keep their own servers.
---@type genja.Lang
return {
	servers = {
		html = {},
	},
}
