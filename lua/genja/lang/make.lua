-- Makefile / Automake / configure.ac
-- autotools_ls (Mason: autotools-language-server) is a pip package, so Python
-- must be on PATH. nvim-lspconfig attaches it to the make, automake and config
-- filetypes; Neovim already detects Makefile, GNUmakefile and *.mk as make.
return {
	servers = {
		autotools_ls = {},
	},
}
