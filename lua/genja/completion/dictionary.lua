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

local SRC = 'completion/dictionary.lua: '

local URL = 'https://raw.githubusercontent.com/dolph/dictionary/master/popular.txt'
local DOWNLOADED = vim.fs.joinpath(vim.fn.stdpath('data'), 'dict', 'en.txt')

local source = require('genja.completion.source')

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
	if line:find('/!') then
		return ''
	end
	return vim.trim(line):match('^[^#/]*')
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
	local mtime = (stat and stat.mtime.sec or 0)
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

---Comma-separated file option as a list, empty items dropped.
---@param value string
---@return string[]
local function file_list(value)
	return vim.split(value, ',', { plain = true, trimempty = true })
end

---@param bufnr integer
---@return string[]
local function files(bufnr)
	local list = file_list(vim.bo[bufnr].dictionary)
	if #list == 0 and vim.uv.fs_stat(DOWNLOADED) then
		list = { DOWNLOADED }
	elseif #list == 0 then
		list = vim.api.nvim_get_runtime_file('dict/en.txt', false)
	end
	local spell = file_list(vim.bo[bufnr].spellfile)
	if #spell == 0 then
		spell = vim.api.nvim_get_runtime_file('spell/*.add', true)
	end
	vim.list_extend(list, spell)
	return vim.tbl_map(vim.fs.normalize, list)
end

---Words starting with the letters before the cursor; capitalised when those start with a capital.
---@param c genja.completion.SourceCtx
---@return lsp.CompletionItem[]
local function items(c)
	local typed = c.before:match('%a+$')
	if not typed or #typed < 2 then
		return {}
	end
	local prefix = typed:lower()
	local upper = (typed:sub(1, 1):match('%u') ~= nil)

	local list, seen = {}, {}
	for _, file in ipairs(files(c.bufnr)) do
		for _, word in ipairs(load(file)[prefix:sub(1, 2)] or {}) do
			if word:lower():sub(1, #prefix) == prefix then
				local label = word
				if upper then
					label = word:sub(1, 1):upper() .. word:sub(2)
				end
				if not seen[label] then
					seen[label] = true
					table.insert(list, { label = label, kind = source.kind.Text })
				end
			end
		end
	end
	return list
end

local function updatePopular()
	local file = DOWNLOADED
	vim.fn.mkdir(vim.fs.dirname(file), 'p')
	vim.system({ 'curl', '-fsSL', '-o', file .. '.tmp', URL }, {}, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				os.remove(file .. '.tmp')
				vim.notify(SRC .. 'DictionaryUpdatePopular: ' .. vim.trim(res.stderr), vim.log.levels.ERROR)
				return
			end
			os.remove(file)
			os.rename(file .. '.tmp', file)
			cache = {}
			vim.notify(SRC .. 'DictionaryUpdatePopular: ' .. file)
		end)
	end)
end

---@type genja.completion.Feature
return function(config)
	local filetypes = { 'text', 'markdown' }
	source.register(config, 'dictionary', {
		filetypes = filetypes,
		with = { 'lsp', 'path', 'buffer' },
		replace = '%a*',
		incomplete = true, -- the list depends on the prefix
		provider = { min_keyword_length = 3, max_items = 20 },
		items = items,
	})
	-- like the buffer words: only when the language server and the path source have nothing
	for _, id in ipairs({ 'lsp', 'path' }) do
		config.sources.providers[id] = vim.tbl_extend('force', config.sources.providers[id] or {}, {
			fallbacks = { 'buffer', 'dictionary' },
		})
	end

	vim.api.nvim_create_user_command('DictionaryUpdatePopular', updatePopular, { desc = 'Download dict/en.txt' })
	-- Start indexing when a buffer opens; the cache is shared, later buffers only check mtimes.
	vim.api.nvim_create_autocmd('FileType', {
		pattern = filetypes,
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
end
