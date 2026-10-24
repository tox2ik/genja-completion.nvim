-- Command-line completion.
---@type genja.completion.Feature
return function(cmp)
	-- <Tab> forward, <S-Tab> back; both open the menu when it is closed.
	local function tab()
		if cmp.visible() then
			cmp.select_next_item()
		else
			cmp.complete()
		end
	end

	local function shift_tab()
		if cmp.visible() then
			cmp.select_prev_item()
		else
			cmp.complete()
		end
	end

	-- <C-j>/<C-k> pick items while the menu is open, else do their native thing.
	local function next_item(fallback)
		if cmp.visible() then
			cmp.select_next_item()
		else
			fallback()
		end
	end

	local function prev_item(fallback)
		if cmp.visible() then
			cmp.select_prev_item()
		else
			fallback()
		end
	end

	-- <Down>/<Up> always recall history; the menu is closed first so it doesn't linger.
	local function history(fallback)
		if cmp.visible() then
			cmp.close()
		end
		fallback()
	end

	-- Explicit, not only the preset: these win over the preset's keys.
	local function mapping()
		return cmp.mapping.preset.cmdline({
			['<Tab>'] = cmp.mapping(tab, { 'c' }),
			['<S-Tab>'] = cmp.mapping(shift_tab, { 'c' }),
			['<C-j>'] = cmp.mapping(next_item, { 'c' }),
			['<C-k>'] = cmp.mapping(prev_item, { 'c' }),
			['<Down>'] = cmp.mapping(history, { 'c' }),
			['<Up>'] = cmp.mapping(history, { 'c' }),
		})
	end

	-- `:` Ex commands and their arguments. This also covers :help topics,
	-- because cmp-cmdline asks Neovim for the same candidates <Tab> would give.
	cmp.setup.cmdline(':', {
		mapping = mapping(),
		sources = cmp.config.sources({
			{ name = 'path' },
		}, {
			{ name = 'cmdline', option = { ignore_cmds = { 'Man', '!', 'w' } } },
		}),
	})

	-- `/` and `?` search: words from the buffer.
	cmp.setup.cmdline({ '/', '?' }, {
		mapping = mapping(),
		sources = {
			{ name = 'buffer' },
		},
	})
end
