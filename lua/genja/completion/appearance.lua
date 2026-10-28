-- Menu and documentation windows. blink draws the kind icons itself (Nerd Font, mono).

---Darken an RGB colour: each channel keeps `keep` of its value (0.4 = 60% darker).
---@param rgb integer 0xRRGGBB
---@param keep number 0..1
---@return integer
local function darken(rgb, keep)
	local r = math.floor(math.floor(rgb / 0x10000) % 0x100 * keep)
	local g = math.floor(math.floor(rgb / 0x100) % 0x100 * keep)
	local b = math.floor(rgb % 0x100 * keep)
	return r * 0x10000 + g * 0x100 + b
end

---Selected item: Normal's text colour on the menu's own background, no highlight bar.
---Typed (matched) letters: bold, in the colours under them.
local function set_colours()
	local normal = vim.api.nvim_get_hl(0, { name = 'Normal', link = false })
	local menu = vim.api.nvim_get_hl(0, { name = 'StatusLine', link = false })
	local bg = menu.bg
	if menu.reverse then -- reversed StatusLine: its fg is what shows as background
		bg = menu.fg
	end
	vim.api.nvim_set_hl(0, 'BlinkCmpMenuSelection', { fg = normal.fg, bg = bg })
	vim.api.nvim_set_hl(0, 'BlinkCmpLabelMatch', { bold = true })
	-- kind icons: PmenuKind's colour without its Pmenu background; BlinkCmpKind<Kind> link here
	local kind = vim.api.nvim_get_hl(0, { name = 'PmenuKind', link = false })
	vim.api.nvim_set_hl(0, 'BlinkCmpKind', { fg = kind.fg })
	-- detail, description and source columns: PmenuExtra's colour without its Pmenu background
	local extra = vim.api.nvim_get_hl(0, { name = 'PmenuExtra', link = false })
	vim.api.nvim_set_hl(0, 'BlinkCmpLabelDetail', { fg = extra.fg })
	vim.api.nvim_set_hl(0, 'BlinkCmpLabelDescription', { fg = extra.fg })
	vim.api.nvim_set_hl(0, 'BlinkCmpSource', { fg = extra.fg })
	vim.api.nvim_set_hl(0, 'BlinkCmpLabelDeprecated', { fg = extra.fg })
	-- scrollbar thumb in the menu's background instead of PmenuThumb's grey
	vim.api.nvim_set_hl(0, 'BlinkCmpScrollBarThumb', { bg = bg })
	-- scrollbar track: the menu background, 60% darker
	if bg then
		vim.api.nvim_set_hl(0, 'BlinkCmpScrollBarGutter', { bg = darken(bg, 0.4) })
	end
end

---@type genja.completion.Feature
return function(config)
	set_colours()
	vim.api.nvim_create_autocmd('ColorScheme', {
		group = vim.api.nvim_create_augroup('genja-completion-colours', { clear = true }),
		callback = set_colours,
	})

	config.completion.menu = {
		winblend = 4,
		scrolloff = 2,
		-- the menu in the StatusLine colours, as with nvim-cmp before
		winhighlight = 'Normal:StatusLine,FloatBorder:NormalFloat,CursorLine:BlinkCmpMenuSelection,Search:None',
		draw = { padding = 1 },
	}
	config.completion.documentation = {
		auto_show = true, -- nvim-cmp showed it for the selected item
		window = { winblend = 4 },
	}
	config.appearance = { nerd_font_variant = 'mono' }
end
