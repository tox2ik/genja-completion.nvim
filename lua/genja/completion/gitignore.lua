-- File and folder names in .gitignore, .ignore and .gitattributes.
-- The path source only starts after ./ or /, but ignore patterns are bare names
-- (node_modules/, src/*.log), so this source lists the directory the ignore
-- file lives in and goes one level deeper after each /.
-- A leading / (anchored) or ! (negated) is skipped; nothing is offered once
-- the directory part has a glob in it.

local source = require('genja.completion.source')

---Directory the patterns are relative to.
---.git/info/exclude and .git/info/attributes are relative to the repo root.
---@param file string
---@return string
local function base_dir(file)
	local dir = vim.fs.dirname(file)
	if vim.fs.basename(dir) == 'info' and vim.fs.basename(vim.fs.dirname(dir)) == '.git' then
		return vim.fs.dirname(vim.fs.dirname(dir))
	end
	return dir
end

---@param c genja.completion.SourceCtx
---@return lsp.CompletionItem[]
local function items(c)
	local file = vim.api.nvim_buf_get_name(c.bufnr)
	if file == '' then
		return {}
	end
	local typed = c.before:gsub('^%s*!?', '')
	local rel = (typed:match('^(.*/)') or ''):gsub('^/', '')
	if rel:find('[*?%[]') then
		return {}
	end
	local list = {}
	for name, type in vim.fs.dir(vim.fs.joinpath(base_dir(file), rel)) do
		if name ~= '.git' then
			local is_dir = (type == 'directory')
			table.insert(list, {
				label = (is_dir and name .. '/' or name),
				filterText = name,
				kind = (is_dir and source.kind.Folder or source.kind.File),
			})
		end
	end
	return list
end

---@type genja.completion.Feature
return function(config)
	source.register(config, 'gitignore', {
		filetypes = { 'gitignore', 'gitattributes' },
		with = { 'buffer' },
		fallbacks = { 'buffer' },
		triggers = { '/' },
		replace = '[^/! \t]*', -- only the last path segment
		incomplete = true, -- a new list after each /
		items = items,
	})
end
