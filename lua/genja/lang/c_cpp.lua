-- C / C++
-- clangd needs compile_commands.json or compile_flags.txt in the project to
-- know the include paths and flags.
return {
	servers = {
		clangd = {},
	},
}
