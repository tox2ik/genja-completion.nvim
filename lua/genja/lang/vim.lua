-- Vimscript
-- vimls (Mason: vim-language-server) is an npm package, so Node must be on PATH.
-- nvim-lspconfig's defaults already set isNeovim and index the runtimepath.
return {
	servers = {
		vimls = {},
	},
}
