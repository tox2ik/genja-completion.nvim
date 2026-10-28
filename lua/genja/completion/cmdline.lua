-- Command-line completion.
--   :      Ex commands and their arguments (file names, :help topics): blink's cmdline source
--   / ?    words from the buffer
-- <Tab>/<S-Tab> open the menu and walk it (blink's cmdline preset); <C-j>/<C-k> and <Down>/<Up> walk it
-- while it is open. With no menu, select_* does nothing and the fallback runs: <Down>/<Up> recall history.
-- <M-x> or <C-e> closes the menu.

---@type genja.completion.Feature
return function(config)
	config.cmdline = {
		keymap = {
			preset = 'cmdline',
			['<C-j>'] = { 'select_next', 'fallback' },
			['<C-k>'] = { 'select_prev', 'fallback' },
			['<Down>'] = { 'select_next', 'fallback' },
			['<Up>'] = { 'select_prev', 'fallback' },
			['<M-x>'] = { 'cancel', 'fallback' }, -- as <C-e>: close the menu, undo the inserted item
		},
		sources = function()
			local type = vim.fn.getcmdtype()
			if type == '/' or type == '?' then
				return { 'buffer' }
			end
			if type == ':' or type == '@' then
				return { 'cmdline' }
			end
			return {}
		end,
		completion = { menu = { auto_show = true } }, -- as with nvim-cmp's cmdline setup
	}
end
