-- Neovim already knows .gitignore, .git/info/exclude and ~/.config/git/ignore.
---@type vim.filetype.add.filetypes
return {
	filename = {
		['.gitignore_global'] = 'gitignore',
		['.ignore'] = 'gitignore', -- ripgrep, fd
		['.rgignore'] = 'gitignore',
		['.fdignore'] = 'gitignore',
	},
}
