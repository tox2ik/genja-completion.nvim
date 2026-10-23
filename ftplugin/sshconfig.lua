-- Parse errors in ssh client config (~/.ssh/config, ssh_config, config.d/*) as
-- diagnostics. There is no language server for ssh config, so ssh itself is
-- the checker.
-- On save: `ssh -G -F <file> <dummy host>`. ssh prints the resolved settings and
-- exits without connecting, but `Match exec` commands still run, and Include
-- is followed (errors in an included file are shown on line 1).
-- Runs while lsp.enabled.sshconfig is true. Needs ssh on PATH (OpenSSH; part of
-- Windows 10+); skipped otherwise, with a notice once per session.

local SRC = 'ftplugin/sshconfig.lua: '

if not require('genja.lsp').enabled('sshconfig') then
	return
end

if vim.fn.executable('ssh') == 0 then
	if not vim.g.genja_ssh_missing_notified then
		vim.g.genja_ssh_missing_notified = true
		vim.notify(SRC .. 'ssh is not on PATH, ssh config parse errors are not checked', vim.log.levels.WARN)
	end
	return
end

local ns = vim.api.nvim_create_namespace('genja.sshconfig')
local buf = vim.api.nvim_get_current_buf()

---@param a string
---@param b string
---@return boolean
local function same_file(a, b)
	a, b = vim.fs.normalize(a), vim.fs.normalize(b)
	if vim.fn.has('win32') == 1 then
		return a:lower() == b:lower()
	end
	return a == b
end

local function check()
	local file = vim.api.nvim_buf_get_name(buf)
	if file == '' or vim.fn.filereadable(file) == 0 then
		return
	end
	vim.system(
		{ 'ssh', '-G', '-F', file, 'genja-parse-only.invalid' },
		{ cwd = vim.fs.dirname(file), text = true },
		vim.schedule_wrap(function(res)
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			-- Unsupported/deprecated options are printed, but ssh carries on.
			local severity = res.code == 0 and vim.diagnostic.severity.WARN or vim.diagnostic.severity.ERROR
			local diags = {}
			for line in (res.stderr or ''):gmatch('[^\r\n]+') do
				-- /home/u/.ssh/config line 5: Bad configuration option: foo
				-- /home/u/.ssh/config: terminating, 1 bad configuration options
				local path, lnum, msg = line:match('^(.-) line (%d+): (.*)$')
				if path and same_file(path, file) then
					table.insert(diags, { lnum = tonumber(lnum) - 1, col = 0, severity = severity, message = msg, source = 'ssh' })
				elseif path then
					table.insert(diags, { lnum = 0, col = 0, severity = severity, message = ('%s line %s: %s'):format(path, lnum, msg), source = 'ssh' })
				elseif res.code ~= 0 and not line:find('terminating, %d+ bad configuration options') then
					table.insert(diags, { lnum = 0, col = 0, severity = severity, message = line, source = 'ssh' })
				end
			end
			vim.diagnostic.set(ns, buf, diags)
		end)
	)
end

local group = vim.api.nvim_create_augroup('genja.sshconfig.' .. buf, { clear = true })
vim.api.nvim_create_autocmd({ 'BufWritePost' }, { group = group, buffer = buf, callback = check })
check()
