-- Simple LSP check: is a language server attached to the current buffer?
--
--   :CheckHealthSimpleLsp        opens a float with the answer
--   <Plug>CheckHealthSimpleLsp   the same, for a key of your choice:
--
--     vim.keymap.set('n', '<leader>ch', '<Plug>CheckHealthSimpleLsp')
--
-- Both are always defined by require('genja.comps').setup(), also with
-- lsp = false. There is no option to turn them off.
--
-- The float shows the verdict, the buffer's file and detected language, and
-- each server with its languages and workspace folders.
--
--   PASS  at least one server is attached to the buffer
--   FAIL  servers run for other buffers only, or no server runs at all

local M = {}

local ns = vim.api.nvim_create_namespace('genja.lsp.check')

---@class genja.lsp.check.Report
---@field lines string[]
---@field highlights (string|false)[] one per line; false: no highlight
---@field verdict 'PASS'|'FAIL'
---@field verdict_hl string highlight group of the verdict

---Workspace folders of a client, falling back to its root dir.
---@param client vim.lsp.Client
---@return string[]
local function workspaces(client)
	local dirs = {}
	for _, folder in ipairs(client.workspace_folders or {}) do
		dirs[#dirs + 1] = vim.uri_to_fname(folder.uri)
	end
	if #dirs == 0 and client.root_dir then
		dirs[1] = client.root_dir
	end
	return dirs
end

---Check a buffer and build the text of the float.
---@param bufnr? integer default: the current buffer
---@return genja.lsp.check.Report
function M.check(bufnr)
	if bufnr == nil or bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end
	local bufname = vim.api.nvim_buf_get_name(bufnr)
	local ft = vim.bo[bufnr].filetype

	local attached, others = {}, {}
	for _, client in ipairs(vim.lsp.get_clients()) do
		table.insert(client.attached_buffers[bufnr] and attached or others, client)
	end
	local function by_id(a, b)
		return a.id < b.id
	end
	table.sort(attached, by_id)
	table.sort(others, by_id)

	local verdict, detail, verdict_hl
	if #attached > 0 then
		verdict, verdict_hl = 'PASS', 'DiagnosticOk'
		detail = ('%d LSP server(s) attached to this buffer'):format(#attached)
	elseif #others > 0 then
		verdict, verdict_hl = 'FAIL', 'DiagnosticWarn'
		detail = ('no LSP server attached to this buffer (%d running for other buffers)'):format(#others)
	else
		verdict, verdict_hl = 'FAIL', 'DiagnosticError'
		detail = 'no active LSP server'
	end

	local lines, highlights = {}, {}
	local function add(text, hl)
		lines[#lines + 1] = text
		highlights[#highlights + 1] = hl or false
	end

	---@param client vim.lsp.Client
	---@param hl? string
	local function describe(client, hl)
		local nbufs = vim.tbl_count(client.attached_buffers)
		add(('  %s (id %d, %d buffer(s))'):format(client.name, client.id, nbufs), hl)
		local filetypes = client.config.filetypes
		if type(filetypes) == 'table' and #filetypes > 0 then
			add('    languages: ' .. table.concat(filetypes, ', '))
		end
		local dirs = workspaces(client)
		if #dirs == 0 then
			add('    workspace: none (single-file mode)')
		end
		for _, dir in ipairs(dirs) do
			add('    workspace: ' .. dir)
		end
	end

	add(verdict .. '  ' .. detail, verdict_hl)
	if verdict == 'FAIL' then
		add('  full LSP report: :checkhealth vim.lsp', 'Comment')
	end
	add('')

	add('Current buffer', 'Title')
	add('  file: ' .. (bufname ~= '' and vim.fn.fnamemodify(bufname, ':~:.') or '[No Name]'))
	add('  language: ' .. (ft ~= '' and ft or 'none detected'))

	if #attached > 0 then
		add('LSP servers attached to this buffer', 'Title')
		for _, client in ipairs(attached) do
			describe(client, 'DiagnosticOk')
		end
	end
	if #others > 0 then
		add('LSP servers running for other buffers', 'Title')
		for _, client in ipairs(others) do
			describe(client)
		end
	end

	return { lines = lines, highlights = highlights, verdict = verdict, verdict_hl = verdict_hl }
end

---Show a report in a float. q or <Esc> closes it.
---@param report genja.lsp.check.Report
local function show(report)
	local lines = report.lines
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	for i, hl in ipairs(report.highlights) do
		if hl then
			vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #lines[i], hl_group = hl })
		end
	end
	vim.bo[buf].bufhidden = 'wipe' -- no hidden buffer left behind per run
	vim.bo[buf].modifiable = false

	-- Sized to the content; the height accounts for wrapped lines.
	local longest = 0
	for _, text in ipairs(lines) do
		longest = math.max(longest, vim.fn.strdisplaywidth(text))
	end
	local max_width = math.max(20, math.floor(vim.o.columns * 0.85))
	local width = math.min(math.max(longest + 2, 50), max_width)
	local height = 0
	for _, text in ipairs(lines) do
		height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(text) / width))
	end
	height = math.max(1, math.min(height, math.floor(vim.o.lines * 0.6)))

	local win = vim.api.nvim_open_win(buf, true, {
		relative = 'editor',
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = 'minimal',
		border = 'rounded',
		title = { { (' LSP check: %s '):format(report.verdict), report.verdict_hl } },
		title_pos = 'center',
	})
	vim.wo[win].wrap = true

	for _, lhs in ipairs({ 'q', '<Esc>' }) do
		vim.keymap.set('n', lhs, '<cmd>close<CR>', { buffer = buf, silent = true, nowait = true })
	end
end

---Check the current buffer and show the result.
function M.open()
	-- Check first: opening the float changes the current buffer.
	show(M.check())
end

---Define :CheckHealthSimpleLsp and <Plug>CheckHealthSimpleLsp.
function M.setup()
	local desc = 'Confirm an LSP server is attached to the current buffer'
	vim.api.nvim_create_user_command('CheckHealthSimpleLsp', function()
		M.open()
	end, { desc = desc })
	vim.keymap.set('n', '<Plug>CheckHealthSimpleLsp', M.open, { desc = desc })
end

return M
