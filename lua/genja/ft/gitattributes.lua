-- Neovim already knows .gitattributes, .git/info/attributes and ~/.config/git/attributes.
---@type vim.filetype.add.filetypes
return {
	filename = {
		['.gitattributes_global'] = 'gitattributes',
	},
}
