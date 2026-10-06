-- Insert-mode keys for the completion menu.
return function(cmp, opts)
	local function has_text_before()
		local col = vim.api.nvim_win_get_cursor(0)[2]
		if col == 0 then
			return false
		end
		return not vim.api.nvim_get_current_line():sub(col, col):match('%s')
	end

	local function tab(fallback)
		if cmp.visible() then
			cmp.select_next_item()
		elseif vim.snippet.active({ direction = 1 }) then
			vim.snippet.jump(1)
		elseif has_text_before() then
			cmp.complete()
		else
			fallback()
		end
	end

	local function shift_tab(fallback)
		if cmp.visible() then
			cmp.select_prev_item()
		elseif vim.snippet.active({ direction = -1 }) then
			vim.snippet.jump(-1)
		else
			fallback()
		end
	end

	opts.mapping = cmp.mapping.preset.insert({
		['<F2>'] = cmp.mapping.select_next_item(),
		['<F3>'] = cmp.mapping.select_prev_item(),
		['<CR>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = false }),
		['<C-k>'] = cmp.mapping.abort(), -- jolemak: <C-e> sends ^K
		['<Tab>'] = cmp.mapping(tab, { 'i', 's' }),
		['<S-Tab>'] = cmp.mapping(shift_tab, { 'i', 's' }),
		['<C-Space>'] = cmp.mapping.complete(),
	})
end
