-- Parse errors in git config files (.gitconfig, .git/config, .gitmodules) as
-- diagnostics. There is no maintained language server for git config, so git
-- itself is the checker.
-- On save: `git config --file <file> --list`. Read-only, and [include] paths
-- are not followed, so only this file is checked.
-- Runs while lsp.enabled.gitconfig is true. Needs git on PATH; skipped
-- otherwise, with a notice once per session.

if not require('genja.lsp').enabled('gitconfig') then
	return
end

if vim.fn.executable('git') == 0 then
	if not vim.g.genja_git_missing_notified then
		vim.g.genja_git_missing_notified = true
		vim.notify('genja: git is not on PATH, git config parse errors are not checked', vim.log.levels.WARN)
	end
	return
end

local ns = vim.api.nvim_create_namespace('genja.gitconfig')
local buf = vim.api.nvim_get_current_buf()

local function check()
	local file = vim.api.nvim_buf_get_name(buf)
	if file == '' or vim.fn.filereadable(file) == 0 then
		return
	end
	vim.system(
		{ 'git', 'config', '--file', file, '--list' },
		{ cwd = vim.fs.dirname(file), text = true },
		vim.schedule_wrap(function(res)
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local diags = {}
			for line in (res.stderr or ''):gmatch('[^\r\n]+') do
				-- fatal: bad config line 5 in file .gitconfig
				local lnum = line:match('bad config line (%d+)')
				if lnum then
					table.insert(diags, { lnum = tonumber(lnum) - 1, col = 0, severity = vim.diagnostic.severity.ERROR, message = 'bad config line', source = 'git' })
				elseif res.code ~= 0 and (line:match('^fatal: ') or line:match('^error: ')) then
					-- fatal: invalid key: ... / error: invalid ... (no line number)
					table.insert(diags, { lnum = 0, col = 0, severity = vim.diagnostic.severity.ERROR, message = line:gsub('^%a+: ', ''), source = 'git' })
				end
			end
			vim.diagnostic.set(ns, buf, diags)
		end)
	)
end

local group = vim.api.nvim_create_augroup('genja.gitconfig.' .. buf, { clear = true })
vim.api.nvim_create_autocmd({ 'BufWritePost' }, { group = group, buffer = buf, callback = check })
check()
