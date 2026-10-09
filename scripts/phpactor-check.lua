-- Isolated phpactor check, without your Neovim config:
--   nvim --clean --headless -l <plugin>/scripts/phpactor-check.lua [project dir]
--
-- Starts phpactor through scripts/phpactor-nocheck.php on a throwaway project
-- (or the given one), then reports:
--   1. the files it needs (php, phpactor.phar, ProcessWrapper64.exe on Windows)
--   2. whether PHP can start a process the way phpactor does (amphp/process)
--   3. diagnostics for a file with a syntax error
--   4. completion of `array_` (built-in functions from the stubs)
-- plus anything phpactor wrote to the LSP log meanwhile. Exit code 0 = all passed.

local is_win = vim.fn.has('win32') == 1
local script = vim.fs.normalize(vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p'))
local wrapper = vim.fs.joinpath(vim.fs.dirname(script), 'phpactor-nocheck.php')
local phar = vim.fs.joinpath(vim.fn.stdpath('data'), 'mason', 'packages', 'phpactor', 'phpactor.phar')
local process_wrapper = vim.fs.joinpath(vim.fs.dirname(phar), 'ProcessWrapper64.exe')

local failed = 0

local function say(...)
	io.stdout:write(table.concat({ ... }, ' ') .. '\n')
end

local function check(ok, label, detail)
	if not ok then
		failed = failed + 1
	end
	say(ok and 'PASS' or 'FAIL', label, detail and ('(' .. detail .. ')') or '')
	return ok
end

say('== files')
local php = vim.fn.exepath('php')
check(php ~= '', 'php on PATH', php)
check(vim.uv.fs_stat(phar) ~= nil, 'phpactor.phar', phar)
check(vim.uv.fs_stat(wrapper) ~= nil, 'wrapper', wrapper)
if is_win then
	check(vim.uv.fs_stat(process_wrapper) ~= nil, 'ProcessWrapper64.exe', process_wrapper)
end
if failed > 0 then
	os.exit(1)
end

-- 2. Start `php -l` through amphp/process with the wrapper's patches loaded, the
-- same way phpactor's "php" diagnostic does. PHPACTOR_CHECK_PROCESS makes the
-- wrapper run this test instead of phpactor.
say('== process start (amphp/process)')
local out = vim.system({ 'php', wrapper, phar }, {
	env = { PHPACTOR_CHECK_PROCESS = '1' },
	text = true,
}):wait(30000)
check(out.code == 0 and out.stdout:find('Parse error', 1, true) ~= nil, 'php -l via amphp',
	vim.trim((out.stdout or '') .. (out.stderr or '')):gsub('%s+', ' '):sub(1, 300))

-- A throwaway project, unless one was given.
local root = _G.arg and _G.arg[1]
local own_root = not root
if own_root then
	root = vim.fn.tempname()
	vim.fn.mkdir(root, 'p')
	vim.fn.writefile({}, vim.fs.joinpath(root, '.phproject'))
end
root = vim.fs.normalize(vim.fn.fnamemodify(root, ':p')):gsub('/$', '')
local bad = vim.fs.joinpath(root, 'phpactor-check-bad.php')
vim.fn.writefile({ '<?php', '', '$x = ;' }, bad)

local log = vim.lsp.log.get_filename()
local log_start = (vim.uv.fs_stat(log) or { size = 0 }).size
-- phpactor's stderr (verbose with -vvv) lands in the LSP log at ERROR level.
vim.lsp.log.set_level('ERROR')

say('== language server', 'root=' .. root)
local diagnostics, messages = nil, {}
local started = vim.uv.hrtime()
vim.cmd.edit(vim.fn.fnameescape(bad))
local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = 'php'
-- genja's own phpactor settings: its cmd (TCP on Windows) and init_options.
local genja = dofile(vim.fs.joinpath(vim.fs.dirname(vim.fs.dirname(script)), 'lua', 'genja', 'lang', 'php.lua'))
local spec = genja.servers.phpactor
say('cmd:', type(spec.cmd) == 'function' and 'TCP (genja)' or 'stdio')
local client_id = vim.lsp.start({
	name = 'phpactor-check',
	cmd = spec.cmd or { 'php', wrapper, phar, 'language-server', '-vvv' },
	root_dir = root,
	init_options = spec.init_options,
	handlers = {
		['textDocument/publishDiagnostics'] = function(_, result)
			-- Log every publish: phpactor first sends an empty list, then the results.
			table.insert(messages, ('%.1fs publishDiagnostics %s: %d'):format(
				(vim.uv.hrtime() - started) / 1e9, result.uri, #result.diagnostics))
			if #result.diagnostics > 0 then
				diagnostics = result.diagnostics
			end
		end,
		['window/showMessage'] = function(_, result)
			table.insert(messages, result.message)
		end,
		['window/logMessage'] = function(_, result)
			if result.type <= 2 then
				table.insert(messages, result.message)
			end
		end,
	},
}, { bufnr = buf })

if not check(client_id ~= nil, 'server started') then
	os.exit(1)
end
local client = vim.lsp.get_client_by_id(client_id)
vim.wait(30000, function()
	return client.initialized
end, 100)
check(client.initialized, 'server initialized', ('%.1fs'):format((vim.uv.hrtime() - started) / 1e9))

vim.wait(60000, function()
	return diagnostics ~= nil and #diagnostics > 0
end, 200)
local texts = vim.tbl_map(function(d)
	return (d.source or '?') .. ': ' .. d.message:gsub('%s+', ' ')
end, diagnostics or {})
check(#texts > 0, 'syntax error diagnostic', #texts > 0 and table.concat(texts, ' | ') or 'none in 60s')

-- 4. Completion of `array_` on a new line. The stubs are indexed on first
-- start, so retry for a while.
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '<?php', '', 'array_' })
local names
vim.wait(120000, function()
	local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	params.position = { line = 2, character = 6 }
	local resp = client:request_sync('textDocument/completion', params, 10000, buf)
	local items = resp and resp.result and (resp.result.items or resp.result) or {}
	names = vim.tbl_filter(function(n)
		return vim.startswith(n, 'array_')
	end, vim.tbl_map(function(i)
		return i.label
	end, items))
	return #names > 5
end, 3000)
check(#names > 5, 'array_ completion', #names .. ' items: ' .. table.concat(vim.list_slice(names, 1, 5), ', '))

client:stop(true)
vim.wait(3000, function()
	return client:is_stopped()
end)
vim.fn.delete(bad)
if own_root then
	vim.fn.delete(root, 'rf')
end

if #messages > 0 then
	say('== phpactor messages')
	for _, m in ipairs(messages) do
		say('  ' .. m:gsub('%s+', ' '):sub(1, 300))
	end
end
local fd = io.open(log, 'r')
if fd then
	fd:seek('set', log_start)
	local new = fd:read('*a')
	fd:close()
	if new ~= '' then
		say('== new LSP log lines (last 8000 characters)')
		say(new:sub(-8000))
	end
end

say(failed == 0 and '== all passed' or ('== ' .. failed .. ' failed'))
os.exit(failed == 0 and 0 or 1)
