-- File and folder names in .gitignore, .ignore and .gitattributes.
-- cmp-path only starts after ./ or /, but ignore patterns are bare names
-- (node_modules/, src/*.log), so this source lists the directory the ignore
-- file lives in and goes one level deeper after each /.
-- A leading / (anchored) or ! (negated) is skipped; nothing is offered once
-- the directory part has a glob in it.

local source = {}

function source.new()
	return setmetatable({}, { __index = source })
end

function source:get_trigger_characters()
	return { '/' }
end

-- Only the last path segment is replaced.
function source:get_keyword_pattern()
	return [=[[^/! \t]*]=]
end

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

function source:complete(params, callback)
	local file = vim.api.nvim_buf_get_name(params.context.bufnr)
	if file == '' then
		return callback({})
	end
	local typed = params.context.cursor_before_line:gsub('^%s*!?', '')
	local rel = (typed:match('^(.*/)') or ''):gsub('^/', '')
	if rel:find('[*?%[]') then
		return callback({})
	end

	local kind = require('cmp').lsp.CompletionItemKind
	local items = {}
	for name, type in vim.fs.dir(vim.fs.joinpath(base_dir(file), rel)) do
		if name ~= '.git' then
			local is_dir = type == 'directory'
			table.insert(items, {
				label = is_dir and name .. '/' or name,
				filterText = name,
				kind = is_dir and kind.Folder or kind.File,
			})
		end
	end
	callback({ items = items, isIncomplete = true })
end

return function(cmp, _)
	cmp.register_source('gitignore', source.new())
	cmp.setup.filetype({ 'gitignore', 'gitattributes' }, {
		sources = cmp.config.sources({
			{ name = 'gitignore', keyword_length = 0 },
		}, {
			{ name = 'buffer' },
		}),
	})
end
