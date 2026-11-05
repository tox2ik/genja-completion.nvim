-- C / C++
-- clangd needs compile_commands.json or compile_flags.txt in the project to know the include
-- paths and flags. For reading C you didn't build:
--   no compilation database: clangd guesses with -I. -Iinclude -Isrc, and its diagnostics are
--     dropped (they'd be false errors on headers it can't find); navigation and hover stay.
--   :CCompileDb  makes one: `cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON` for a CMake
--     project, else `bear -- make` for a Makefile one; then restarts clangd.

local SRC = 'lang/c_cpp.lua: '

local DB_FILES = { 'compile_commands.json', 'compile_flags.txt', 'build/compile_commands.json' }

---@param root string|nil
---@return boolean
local function has_db(root)
	if not root then
		return false
	end
	for _, name in ipairs(DB_FILES) do
		if vim.uv.fs_stat(vim.fs.joinpath(root, name)) then
			return true
		end
	end
	return false
end

vim.api.nvim_create_user_command('CCompileDb', function()
	local root = vim.fs.root(0, { 'CMakeLists.txt', 'Makefile', 'makefile', 'GNUmakefile', '.git' })
	if not root then
		vim.notify(SRC .. 'no CMakeLists.txt or Makefile above this file', vim.log.levels.WARN)
		return
	end
	local cmd
	if vim.uv.fs_stat(vim.fs.joinpath(root, 'CMakeLists.txt')) and vim.fn.executable('cmake') == 1 then
		cmd = { 'cmake', '-S', '.', '-B', 'build', '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON' }
	elseif vim.fn.executable('bear') == 1 then
		cmd = { 'bear', '--', 'make' }
	else
		vim.notify(SRC .. 'needs cmake (CMake project) or bear (Makefile project) on PATH', vim.log.levels.WARN)
		return
	end
	vim.notify(SRC .. table.concat(cmd, ' ') .. ' in ' .. root .. ' …')
	vim.system(cmd, { cwd = root, text = true }, vim.schedule_wrap(function(res)
		if res.code ~= 0 or not has_db(root) then
			vim.notify(SRC .. 'no compilation database: ' .. vim.trim(res.stderr or ''), vim.log.levels.ERROR)
			return
		end
		vim.notify(SRC .. 'compilation database written; restarting clangd')
		pcall(vim.cmd, 'LspRestart clangd')
	end))
end, { desc = 'C: write compile_commands.json (cmake or bear), restart clangd' })

---@type genja.Lang
return {
	servers = {
		clangd = {
			init_options = { fallbackFlags = { '-I.', '-Iinclude', '-Isrc' } },
			handlers = {
				-- without a database the errors are mostly missing headers: keep navigation, drop them
				['textDocument/publishDiagnostics'] = function(err, result, ctx)
					local client = vim.lsp.get_client_by_id(ctx.client_id)
					if client and has_db(client.root_dir) then
						vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
					end
				end,
			},
		},
	},
}
