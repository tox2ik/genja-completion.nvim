-- English words in text and markdown buffers.
-- Words come from the buffer's 'dictionary' option when it is set, otherwise
-- from stdpath('data')/dict/en.txt when it exists, else from the first
-- dict/en.txt on the runtimepath (one word per line), plus the
-- words you added with zg (the files in 'spellfile', or spell/*.add on the
-- runtimepath). A capitalised prefix gets capitalised words.
--
-- dict/en.txt is popular.txt from https://github.com/dolph/dictionary
-- (about 25k common English words; built from the public-domain ENABLE list
-- and Wiktionary word frequencies). :DictionaryUpdatePopular downloads the current
-- version to stdpath('data')/dict/en.txt, which then wins over dict/en.txt on
-- the runtimepath.

local URL = 'https://raw.githubusercontent.com/dolph/dictionary/master/popular.txt'
local DOWNLOADED = vim.fs.joinpath(vim.fn.stdpath('data'), 'dict', 'en.txt')

local source = {}

---@class genja.completion.DictEntry
---@field mtime integer
---@field index table<string, string[]> first two letters (lower case) -> words
---@field done boolean

---@type table<string, genja.completion.DictEntry>
local cache = {}

local CHUNK = 2000 -- words indexed per main-loop step

---@param line string
---@return string
local function word_of(line)
	-- .add files: '#' comments, word/flags, and word/! for words removed with zw
	return not line:find('/!') and vim.trim(line):match('^[^#/]*') or ''
end

---@param entry genja.completion.DictEntry
---@param lines string[]
local function index_chunked(entry, lines)
	local i = 1
	-- Index CHUNK lines, then yield to the main loop so typing and redraws stay smooth.
	local function step()
		for n = i, math.min(i + CHUNK - 1, #lines) do
			local word = word_of(lines[n])
			if #word > 2 then
				local key = word:sub(1, 2):lower()
				entry.index[key] = entry.index[key] or {}
				table.insert(entry.index[key], word)
			end
		end
		i = i + CHUNK
		if i <= #lines then
			vim.schedule(step)
		else
			entry.done = true
		end
	end
	step()
end

---@param file string
---@param entry genja.completion.DictEntry
local function read_async(file, entry)
	local uv = vim.uv
	uv.fs_open(file, 'r', 438, function(err, fd)
		if err or not fd then
			return
		end
		uv.fs_fstat(fd, function(err_stat, stat)
			if err_stat or not stat then
				return uv.fs_close(fd)
			end
			uv.fs_read(fd, stat.size, 0, function(err_read, data)
				uv.fs_close(fd)
				-- libuv callbacks run in a fast context; hop to the main loop for vim.* calls.
				vim.schedule(function()
					-- Drop the result if a newer build replaced this entry meanwhile.
					if not err_read and cache[file] == entry then
						index_chunked(entry, vim.split(data or '', '\n', { plain = true }))
					end
				end)
			end)
		end)
	end)
end

---Words of `file` by their first two letters (lower case). Never blocks: a new
---or changed file is read and indexed in the background, and until that is
---finished this returns the words indexed so far.
---@param file string
---@return table<string, string[]>
local function load(file)
	local stat = vim.uv.fs_stat(file)
	local mtime = stat and stat.mtime.sec or 0
	if cache[file] and cache[file].mtime == mtime then
		return cache[file].index
	end
	local entry = { mtime = mtime, index = {}, done = false }
	cache[file] = entry
	if stat then
		read_async(file, entry)
	end
	return entry.index
end

---@param bufnr integer
---@return string[]
local function files(bufnr)
	local list = vim.tbl_filter(function(f)
		return f ~= ''
	end, vim.split(vim.bo[bufnr].dictionary, ',', { plain = true }))
	if #list == 0 then
		list = vim.uv.fs_stat(DOWNLOADED) and { DOWNLOADED }
			or vim.api.nvim_get_runtime_file('dict/en.txt', false)
	end
	local spell = vim.tbl_filter(function(f)
		return f ~= ''
	end, vim.split(vim.bo[bufnr].spellfile, ',', { plain = true }))
	if #spell == 0 then
		spell = vim.api.nvim_get_runtime_file('spell/*.add', true)
	end
	vim.list_extend(list, spell)
	return vim.tbl_map(vim.fs.normalize, list)
end

function source.new()
	return setmetatable({}, { __index = source })
end

function source:get_keyword_pattern()
	return [[\a\+]]
end

function source:complete(params, callback)
	local typed = params.context.cursor_before_line:match('%a+$')
	if not typed or #typed < 2 then
		return callback({})
	end
	local prefix = typed:lower()
	local upper = typed:sub(1, 1):match('%u') ~= nil

	local kind = require('cmp').lsp.CompletionItemKind.Text
	local items, seen = {}, {}
	for _, file in ipairs(files(params.context.bufnr)) do
		for _, word in ipairs(load(file)[prefix:sub(1, 2)] or {}) do
			if word:lower():sub(1, #prefix) == prefix then
				local label = upper and word:sub(1, 1):upper() .. word:sub(2) or word
				if not seen[label] then
					seen[label] = true
					table.insert(items, { label = label, kind = kind })
				end
			end
		end
	end
	callback({ items = items, isIncomplete = true })
end

local function updatePopular()
	local file = DOWNLOADED
	vim.fn.mkdir(vim.fs.dirname(file), 'p')
	vim.system({ 'curl', '-fsSL', '-o', file .. '.tmp', URL }, {}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				os.remove(file .. '.tmp')
				vim.notify('DictionaryUpdatePopular: ' .. vim.trim(res.stderr), vim.log.levels.ERROR)
				return
			end
			os.remove(file)
			os.rename(file .. '.tmp', file)
			cache = {}
			vim.notify('DictionaryUpdatePopular: ' .. file)
		end)
	end)
end

---@type genja.completion.Feature
return function(cmp, _)
	cmp.register_source('dictionary', source.new())
	vim.api.nvim_create_user_command('DictionaryUpdatePopular', updatePopular, { desc = 'Download dict/en.txt' })
	-- Start indexing when a buffer opens; the cache is shared, later buffers only check mtimes.
	vim.api.nvim_create_autocmd('FileType', {
		pattern = { 'text', 'markdown' },
		group = vim.api.nvim_create_augroup('genja.completion.dictionary', {}),
		callback = function(ev)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(ev.buf) then
					for _, file in ipairs(files(ev.buf)) do
						load(file)
					end
				end
			end)
		end,
	})
	cmp.setup.filetype({ 'text', 'markdown' }, {
		sources = cmp.config.sources({
			{ name = 'nvim_lsp' },
			{ name = 'path' },
		}, {
			{ name = 'buffer' },
			{ name = 'dictionary', keyword_length = 3, max_item_count = 20 },
		}),
	})
end
