-- Parse errors from GNU make itself ("missing separator" and the like) as
-- diagnostics. autotools_ls does not run make, so it never reports these.
-- On save: `make -n -f <file> <no-such-target>`. The file is parsed, nothing is
-- built (no recipe matches the target), but $(shell ...) at top level still runs.
-- Runs while lsp.enabled.make is true. Needs GNU make on PATH; skipped
-- otherwise, with a notice once per session.

local SRC = 'ftplugin/make.lua: '

if not require('genja.lsp').enabled('make') then
	return
end

if vim.fn.executable('make') == 0 then
	if not vim.g.genja_make_missing_notified then
		vim.g.genja_make_missing_notified = true
		vim.notify(SRC .. 'make is not on PATH, Makefile parse errors are not checked', vim.log.levels.WARN)
	end
	return
end

local ns = vim.api.nvim_create_namespace('genja.make')
local buf = vim.api.nvim_get_current_buf()

local function check()
	local file = vim.api.nvim_buf_get_name(buf)
	if file == '' then
		return
	end
	vim.system(
		{ 'make', '-n', '-f', file, '__genja_parse_only__' },
		{ cwd = vim.fs.dirname(file), text = true },
		vim.schedule_wrap(function(res)
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local diags = {}
			for line in ((res.stderr or '') .. (res.stdout or '')):gmatch('[^\r\n]+') do
				-- make: Makefile:5: *** missing separator.  Stop.
				-- Makefile:9: warning: overriding recipe for target 'x'
				local lnum, msg = line:match(':(%d+): %*%*%* (.-)%s*Stop%.$')
				local severity = vim.diagnostic.severity.ERROR
				if not lnum then
					lnum, msg = line:match(':(%d+): warning: (.*)$')
					severity = vim.diagnostic.severity.WARN
				end
				if lnum then
					table.insert(diags, { lnum = tonumber(lnum) - 1, col = 0, severity = severity, message = msg, source = 'make' })
				end
			end
			vim.diagnostic.set(ns, buf, diags)
		end)
	)
end

local group = vim.api.nvim_create_augroup('genja.make.' .. buf, { clear = true })
vim.api.nvim_create_autocmd({ 'BufWritePost' }, { group = group, buffer = buf, callback = check })
check()
