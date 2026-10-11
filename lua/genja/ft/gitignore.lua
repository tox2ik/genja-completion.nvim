-- Neovim already knows .gitignore, .git/info/exclude and ~/.config/git/ignore.
return {
	filename = {
		['.gitignore_global'] = 'gitignore',
		['.ignore'] = 'gitignore', -- ripgrep, fd
		['.rgignore'] = 'gitignore',
		['.fdignore'] = 'gitignore',
	},
}
