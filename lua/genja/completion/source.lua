-- Builds the blink.cmp sources of this plugin (gitignore, sshconfig, gitcommit, dictionary) and
-- registers them. Each source is a function from the text before the cursor to completion
-- items; this file turns it into what blink wants (source.new, get_completions, a module name).
--
--   local source = require('genja.completion.source')
--   source.register(config, 'gitignore', {
--   	filetypes = { 'gitignore', 'gitattributes' },
--   	triggers = { '/' },
--   	replace = '[^/! \t]*',                  -- the text the item replaces, before the cursor
--   	items = function(c) return { { label = 'x', kind = source.kind.File } } end,
--   })

local M = {}

---What a source's `items` function gets.
---@class genja.completion.SourceCtx
---@field bufnr integer
---@field row integer 1-based
---@field before string line text before the cursor

---@class genja.completion.SourceSpec
---@field items fun(c: genja.completion.SourceCtx): lsp.CompletionItem[]
---@field filetypes? string[] only there (sources.per_filetype); nil: every filetype
---@field with? string[] providers listed after this one in its filetypes, e.g. { 'path', 'buffer' }
---@field fallbacks? string[] shown only when this source has nothing
---@field triggers? string[] characters that open the menu
---@field replace? string Lua pattern of the text the items replace, ending at the cursor; nil: blink's keyword
---@field incomplete? boolean ask again on each typed character (the source filters itself)
---@field enabled? fun(): boolean
---@field provider? table more blink provider options (min_keyword_length, max_items, ...)
---@field only? boolean registered as a provider but in no list; the feature picks it per context (sources function)

---Item kinds, as blink numbers them (the LSP ones).
M.kind = require('blink.cmp.types').CompletionItemKind

---Built sources by id; blink requires this module for each of them and calls M.new(opts).
---@type table<string, table>
local sources = {}

---Set a textEdit on every item: it replaces `pattern` before the cursor, so text blink
---doesn't count as a keyword (`@`, `.`, `/`) is replaced too.
---@param items lsp.CompletionItem[]
---@param pattern string
---@param row integer 1-based
---@param before string
local function set_edits(items, pattern, row, before)
	local start = #before - #(before:match(pattern .. '$') or '')
	local range = {
		start = { line = row - 1, character = start },
		['end'] = { line = row - 1, character = #before },
	}
	for _, item in ipairs(items) do
		item.textEdit = { newText = item.insertText or item.label, range = range }
	end
end

---A blink source (the table `module` names) from a spec.
---@param spec genja.completion.SourceSpec
---@return table
local function build(spec)
	local source = {}

	function source.new()
		return setmetatable({}, { __index = source })
	end

	function source:enabled()
		return spec.enabled == nil or spec.enabled()
	end

	function source:get_trigger_characters()
		return spec.triggers or {}
	end

	function source:get_completions(ctx, callback)
		local row, col = ctx.cursor[1], ctx.cursor[2]
		local before = ctx.line:sub(1, col)
		local items = spec.items({ bufnr = ctx.bufnr, row = row, before = before }) or {}
		if spec.replace then
			set_edits(items, spec.replace, row, before)
		end
		local incomplete = (spec.incomplete == true)
		callback({ items = items, is_incomplete_forward = incomplete, is_incomplete_backward = incomplete })
	end

	return source
end

---Add source `id` to the blink config: its provider, and its place in `filetypes`.
---@param config blink.cmp.Config
---@param id string
---@param spec genja.completion.SourceSpec
function M.register(config, id, spec)
	sources[id] = build(spec)
	config.sources.providers[id] = vim.tbl_extend('force', {
		name = id,
		module = 'genja.completion.source',
		opts = { id = id },
		fallbacks = spec.fallbacks,
	}, spec.provider or {})

	if spec.only then
		return
	end
	if not spec.filetypes then
		table.insert(config.sources.default, id)
		return
	end
	for _, ft in ipairs(spec.filetypes) do
		config.sources.per_filetype[ft] = vim.list_extend({ id }, spec.with or {})
	end
end

---blink's constructor for every provider registered above.
---@param opts { id: string }
---@return table
function M.new(opts)
	return sources[opts.id].new()
end

---Items with one kind from labels.
---@param labels string[]
---@param kind integer M.kind.*
---@return lsp.CompletionItem[]
function M.labels(labels, kind)
	return vim.tbl_map(function(label) return { label = label, kind = kind } end, labels)
end

return M
