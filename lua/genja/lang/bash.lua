-- Bash / sh
-- bashls runs shellcheck (diagnostics) and shfmt (formatting) when they are on PATH.
---@type genja.Lang
return {
	servers = {
		bashls = {},
	},
	tools = { 'shellcheck', 'shfmt' },
}
