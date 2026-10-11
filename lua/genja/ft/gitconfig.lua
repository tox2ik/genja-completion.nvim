-- Neovim already knows .gitconfig, .gitmodules, .git/config and ~/.config/git/config.
return {
	extension = {
		gitconfig = 'gitconfig', -- work.gitconfig (includeIf targets)
	},
	pattern = {
		['.*/%.gitconfig[%.%-_].+'] = 'gitconfig', -- .gitconfig.local, .gitconfig-work
	},
}
