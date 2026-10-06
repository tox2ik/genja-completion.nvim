-- Bash / sh
-- bashls runs shellcheck (diagnostics) and shfmt (formatting) when they are on PATH.
return {
	servers = {
		bashls = {},
	},
	tools = { 'shellcheck', 'shfmt' },
}
