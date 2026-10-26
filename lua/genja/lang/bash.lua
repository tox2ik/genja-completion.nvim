-- Bash / sh
-- bashls runs shellcheck (diagnostics) and shfmt (formatting) when they are on PATH.
-- Windows: bashls (Node) can't start mason's shellcheck.cmd launcher by name and logs
-- "ShellCheck: disabling linting as no executable was found at path 'shellcheck'", so it gets
-- the full path of mason's shellcheck.exe when that exists.

local settings = {}
if vim.fn.has('win32') == 1 then
	local exe = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'shellcheck', 'shellcheck.exe')
	if vim.uv.fs_stat(exe) then
		settings = { bashIde = { shellcheckPath = vim.fs.normalize(exe) } }
	end
end

---@type genja.Lang
return {
	servers = {
		bashls = { settings = settings },
	},
	tools = { 'shellcheck', 'shfmt' },
}
