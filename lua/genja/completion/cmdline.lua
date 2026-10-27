-- Command-line completion.
--   :      Ex commands and their arguments (file names, :help topics): blink's cmdline source
--   / ?    words from the buffer
-- <Tab>/<S-Tab> open the menu and walk it (blink's cmdline preset), <C-j>/<C-k> walk it while
-- it is open, <Down>/<Up> always recall history (the menu closes first).

---Close the menu, then let the key do its own thing (history).
---@param cmp table blink.cmp
local function hide(cmp)
	if cmp.is_menu_visible() then
		cmp.hide()
	end
end

---@type genja.completion.Feature
return function(config)
	config.cmdline = {
		keymap = {
			preset = 'cmdline',
			['<C-j>'] = { 'select_next', 'fallback' },
			['<C-k>'] = { 'select_prev', 'fallback' },
			['<Down>'] = { hide, 'fallback' },
			['<Up>'] = { hide, 'fallback' },
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
