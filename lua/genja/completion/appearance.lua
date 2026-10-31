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
	-- documentation: the menu's colours; the frame in PmenuExtra's colour on that background
	local fg = menu.fg
	if menu.reverse then
		fg = menu.bg
	end
	vim.api.nvim_set_hl(0, 'BlinkCmpDoc', { fg = fg, bg = bg })
	vim.api.nvim_set_hl(0, 'BlinkCmpDocBorder', { fg = extra.fg, bg = bg })
	vim.api.nvim_set_hl(0, 'BlinkCmpDocSeparator', { fg = extra.fg, bg = bg })
end

---One space of padding left and right of each documentation line. blink has no padding
---option; it sizes the window from the line widths, so the spaces widen it too. Text is
---inserted, not replaced, so blink's highlight extmarks move with it.
---@param buf integer
local function pad_docs(buf)
	-- blink's renderer sets the buffer back to not modifiable when it is done
	vim.bo[buf].modifiable = true
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	for i, line in ipairs(lines) do
		vim.api.nvim_buf_set_text(buf, i - 1, #line, i - 1, #line, { ' ' })
		vim.api.nvim_buf_set_text(buf, i - 1, 0, i - 1, 0, { ' ' })
	end
	vim.bo[buf].modifiable = false
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
		window = {
			-- 0 solid .. 100 clear; 4 is barely see-through, same as the menu (needs termguicolors)
			winblend = 4,
			-- ╭─╮ frame in FloatBorder, mapped to BlinkCmpDocBorder below;
			-- other styles: 'none', 'single', 'double', 'solid', 'shadow', or 8 chars; unset uses 'winborder'.
			-- With a border blink draws only the scrollbar thumb, no gutter (BlinkCmpScrollBarGutter shows in the menu only)
			border = 'shadow', -- 'rounded',
			winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc',
		},
		draw = function(opts)
			opts.default_implementation()
			pad_docs(opts.window:get_buf())
		end,
	}
	config.appearance = { nerd_font_variant = 'mono' }
end
