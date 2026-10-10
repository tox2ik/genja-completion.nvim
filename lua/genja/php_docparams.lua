-- :PhpDocParams adds `@param <type> $name` for every parameter of every function
-- and method in the buffer (or in the selected lines) that its docblock doesn't
-- list yet, and `@return <type>` if it has none, creating the docblock if there
-- is none. Existing tags are left alone.
--
-- Neither phpactor nor intelephense do this file-wide: phpactor's "Add missing
-- @param tags" only covers class methods, and only where the tag adds type
-- information beyond the signature.
--
-- The type is the declared one; without one it's guessed from the default value
-- (string, int, float, bool, array), else `mixed`. The return type is the
-- declared one, else `void` when nothing is returned, `\Generator` when it
-- yields, else `mixed`; constructors get none. Uses the treesitter `php` parser.

local M = {}

local function text(node, buf)
	return node and vim.treesitter.get_node_text(node, buf) or nil
end

---Docblock type for a parameter without a declared type, from its default value.
---@param default TSNode?
local function guess_type(default)
	local kinds = {
		string = 'string',
		encapsed_string = 'string',
		integer = 'int',
		float = 'float',
		boolean = 'bool',
		array_creation_expression = 'array',
	}
	return default and kinds[default:type()] or 'mixed'
end

---The parameters of a function or method node as { type, name } pairs.
---@param fn TSNode
---@param buf integer
---@return { type: string, name: string }[]
local function parameters(fn, buf)
	local params = {}
	local list = fn:field('parameters')[1]
	if not list then
		return params
	end
	for param in list:iter_children() do
		local kind = param:type()
		if kind == 'simple_parameter' or kind == 'variadic_parameter' or kind == 'property_promotion_parameter' then
			local name = text(param:field('name')[1], buf)
			if name then
				local type = text(param:field('type')[1], buf)
					or guess_type(param:field('default_value')[1])
				if kind == 'variadic_parameter' then
					name = '...' .. name
				end
				table.insert(params, { type = type, name = name })
			end
		end
	end
	return params
end

---The docblock right above node, if any.
---@param node TSNode
---@param buf integer
---@return TSNode?
local function docblock(node, buf)
	local prev = node:prev_sibling()
	if prev and prev:type() == 'comment' and vim.startswith(text(prev, buf), '/**') then
		local prev_end = prev:end_()
		if node:start() - prev_end <= 1 then
			return prev
		end
	end
end

---Docblock type for what fn returns: the declared type, else `void` when no
---`return` in its own body returns a value, else `mixed`. Nil for constructors
---and destructors, which take no @return.
---@param fn TSNode
---@param buf integer
---@return string?
local function return_type(fn, buf)
	local name = text(fn:field('name')[1], buf)
	if name == '__construct' or name == '__destruct' then
		return
	end
	local declared = text(fn:field('return_type')[1], buf)
	if declared then
		return declared
	end
	local body = fn:field('body')[1]
	if not body then
		return 'mixed' -- abstract or interface method
	end
	-- Look for `return <value>;` or `yield`, skipping nested functions and classes.
	local nested = {
		anonymous_function = true,
		arrow_function = true,
		function_definition = true,
		class_declaration = true,
		object_creation_expression = true,
	}
	local found
	local function walk(node)
		for child in node:iter_children() do
			local kind = child:type()
			if kind == 'yield_expression' then
				found = '\\Generator'
			elseif kind == 'return_statement' and child:named_child_count() > 0 then
				found = found or 'mixed'
			elseif not nested[kind] then
				walk(child)
			end
		end
	end
	walk(body)
	return found or 'void'
end

---Lines to write for fn: a replacement for its docblock rows, or a new docblock.
---@param fn TSNode
---@param buf integer
---@return integer? start_row, integer? end_row, string[]? lines
local function edit_for(fn, buf)
	local params = parameters(fn, buf)
	local ret = return_type(fn, buf)
	local row = fn:start()
	local indent = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]:match('^%s*')
	local function param_line(p)
		return ('%s * @param %s %s'):format(indent, p.type, p.name)
	end
	local return_line = ret and ('%s * @return %s'):format(indent, ret)

	local doc = docblock(fn, buf)
	if not doc then
		if #params == 0 and not ret then
			return
		end
		local lines = { indent .. '/**' }
		for _, p in ipairs(params) do
			table.insert(lines, param_line(p))
		end
		if return_line then
			table.insert(lines, return_line)
		end
		table.insert(lines, indent .. ' */')
		return row, row, lines
	end

	local doc_start, _, doc_end = doc:range()
	local lines = vim.api.nvim_buf_get_lines(buf, doc_start, doc_end + 1, false)
	local body = text(doc, buf)
	local missing = vim.tbl_filter(function(p)
		-- `@param type $name`, `@param $name`, with or without `...` or `&`.
		local name = p.name:gsub('^%.%.%.', '')
		return not body:find('@param[^\n]-[%s&.]' .. vim.pesc(name) .. '%f[^%w_]')
	end, params)
	if body:find('@return', 1, true) then
		return_line = nil
	end
	if #missing == 0 and not return_line then
		return
	end

	-- A one-line docblock (`/** Text */`) becomes multi-line first.
	if #lines == 1 then
		local one = lines[1]
		local inner = vim.trim(one:match('/%*%*(.-)%*/') or '')
		local prefix = one:match('^(.-)/%*%*')
		lines = { prefix .. '/**' }
		if inner ~= '' then
			table.insert(lines, indent .. ' * ' .. inner)
			table.insert(lines, indent .. ' *')
		end
		table.insert(lines, indent .. ' */')
	end

	-- @param after the last @param, else before the first other tag, else before */.
	local at
	for i, line in ipairs(lines) do
		if line:find('@param', 1, true) then
			at = i + 1
		end
	end
	if not at then
		for i, line in ipairs(lines) do
			if line:find('^%s*%*%s*@') then
				at = i
				break
			end
		end
	end
	at = at or #lines

	local new = vim.tbl_map(param_line, missing)
	for i = #new, 1, -1 do
		table.insert(lines, at, new[i])
	end
	-- @return right after the params, so before @throws and the rest.
	if return_line then
		table.insert(lines, at + #new, return_line)
	end
	return doc_start, doc_end + 1, lines
end

---Add the missing @param tags in buf, between rows first and last (0-based, inclusive).
---@param buf integer
---@param first integer?
---@param last integer?
---@return integer count functions changed
function M.run(buf, first, last)
	buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
	local ok, parser = pcall(vim.treesitter.get_parser, buf, 'php')
	if not ok or not parser then
		vim.notify('PhpDocParams: no treesitter php parser (:TSInstall php)', vim.log.levels.WARN)
		return 0
	end
	local tree = parser:parse()[1]
	local query = vim.treesitter.query.parse('php', '[(function_definition) (method_declaration)] @fn')

	local edits = {}
	for _, fn in query:iter_captures(tree:root(), buf, first, last and last + 1) do
		local row = fn:start()
		if (not first or row >= first) and (not last or row <= last) then
			local s, e, lines = edit_for(fn, buf)
			if s then
				table.insert(edits, { s, e, lines })
			end
		end
	end

	-- Bottom-up, so earlier rows stay where they are.
	table.sort(edits, function(a, b)
		return a[1] > b[1]
	end)
	for _, edit in ipairs(edits) do
		vim.api.nvim_buf_set_lines(buf, edit[1], edit[2], false, edit[3])
	end
	return #edits
end

---Add :PhpDocParams to buf. Takes a range; the whole buffer without one.
---@param buf integer
function M.attach(buf)
	vim.api.nvim_buf_create_user_command(buf, 'PhpDocParams', function(cmd)
		local first, last
		if cmd.range > 0 then
			first, last = cmd.line1 - 1, cmd.line2 - 1
		end
		local count = M.run(buf, first, last)
		vim.notify(('PhpDocParams: updated %d function%s'):format(count, count == 1 and '' or 's'))
	end, { range = true, desc = 'Add missing @param and @return tags to every function and method' })
end

return M
