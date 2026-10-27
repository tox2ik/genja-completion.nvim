-- Conventional Commits parts in gitcommit buffers:
--   summary line, before '(' or ':': the types (feat, fix, ...);
--   after 'type(': scopes used before in `git log`, most used first;
--   body lines, at the start: footers (BREAKING CHANGE:, Refs:, Co-authored-by:).
-- Only while genja-commit's Conventional Commits mode is on for the buffer
-- (b:genja_commit_conventional); nothing without genja-commit.nvim.

local TYPES = {
	feat = 'a new feature',
	fix = 'a bug fix',
	docs = 'documentation only',
	style = 'formatting, no code change',
	refactor = 'neither fixes a bug nor adds a feature',
	perf = 'performance',
	test = 'tests only',
	build = 'build system or dependencies',
	ci = 'CI configuration',
	chore = 'other changes outside src and tests',
	revert = 'reverts an earlier commit',
}
local DEFAULT_ORDER = { 'feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore', 'revert' }

local FOOTERS = {
	{ label = 'BREAKING CHANGE: ', doc = 'breaking change; also put ! after type(scope)' },
	{ label = 'Refs: #', doc = 'related issue' },
	{ label = 'Co-authored-by: ', doc = 'Name <email>' },
}

local source = require('genja.completion.source')

---@type table<integer, string[]> scopes by buffer, read once
local scope_cache = {}

---genja-commit's type list (opt conventional_types), else the standard one.
---@return string[]
local function type_list()
	local ok, config = pcall(require, 'genja-commit.config')
	if ok then
		return config.get().conventional_types
	end
	return DEFAULT_ORDER
end

---Scopes from earlier subjects, most used first.
---@param buf integer
---@return string[]
local function scopes(buf)
	if scope_cache[buf] then
		return scope_cache[buf]
	end
	local dir = vim.b[buf].genja_commit_dir or vim.fn.getcwd()
	local res = vim.system({ 'git', 'log', '-500', '--format=%s' }, { cwd = dir, text = true }):wait()
	local counts = {}
	for line in (res.stdout or ''):gmatch('[^\n]+') do
		local scope = line:match('^[%w-]+%(([^)]+)%)!?:')
		if scope then
			counts[scope] = (counts[scope] or 0) + 1
		end
	end
	local list = vim.tbl_keys(counts)
	table.sort(list, function(a, b)
		if counts[a] ~= counts[b] then
			return counts[a] > counts[b]
		end
		return a < b
	end)
	scope_cache[buf] = list
	vim.api.nvim_create_autocmd('BufWipeout', {
		buffer = buf,
		once = true,
		callback = function() scope_cache[buf] = nil end,
	})
	return list
end

---@param c genja.completion.SourceCtx
---@return lsp.CompletionItem[]
local function items(c)
	local kind = source.kind
	if c.row == 1 and c.before:match('^[%w-]*$') then
		return vim.tbl_map(function(name)
			return { label = name, kind = kind.Keyword, documentation = TYPES[name] }
		end, type_list())
	end
	if c.row == 1 and c.before:match('^[%w-]+%([%w-]*$') then
		local list = {}
		for i, scope in ipairs(scopes(c.bufnr)) do
			-- sortText keeps "most used first"
			table.insert(list, { label = scope, kind = kind.EnumMember, sortText = ('%04d'):format(i) })
		end
		return list
	end
	if c.row >= 3 and c.before:match('^[%w-]*$') then
		return vim.tbl_map(function(footer)
			return { label = footer.label, kind = kind.Text, documentation = footer.doc }
		end, FOOTERS)
	end
	return {}
end

---@type genja.completion.Feature
return function(config)
	source.register(config, 'gitcommit', {
		filetypes = { 'gitcommit' },
		with = { 'buffer' },
		fallbacks = { 'buffer' },
		triggers = { '(' },
		enabled = function()
			return vim.bo.filetype == 'gitcommit' and vim.b.genja_commit_conventional == true
		end,
		items = items,
	})
end
