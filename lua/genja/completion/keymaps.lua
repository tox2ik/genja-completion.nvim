-- Insert-mode keys for the completion menu: blink's default preset plus these.
-- blink's default selection: the first item is preselected and <CR> takes it.

---Is there non-blank text right before the cursor?
---@return boolean
local function has_text_before()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	if col == 0 then
		return false
	end
	return not vim.api.nvim_get_current_line():sub(col, col):match('%s')
end

---@type genja.completion.Feature
return function(config)
	config.keymap = {
		preset = 'default',
		-- next item, else next snippet field, else open the menu after text, else a real <Tab>
		['<Tab>'] = {
			'select_next',
			'snippet_forward',
			function(cmp)
				if has_text_before() then
					return cmp.show()
				end
			end,
			'fallback',
		},
		['<S-Tab>'] = { 'select_prev', 'snippet_backward', 'fallback' },
		['<CR>'] = { 'accept', 'fallback' },
		['<F2>'] = { 'select_next', 'fallback' },
		['<F3>'] = { 'select_prev', 'fallback' },
		-- jolemak: <C-e> sends ^K, so this is the layout's <C-e>
		['<C-k>'] = { 'cancel', 'fallback' },
	}

	-- The old nvim-cmp behaviour: nothing preselected, <CR> accepts only an item picked with <Tab>.
	-- config.completion.list = { selection = { preselect = false, auto_insert = true } }
end
