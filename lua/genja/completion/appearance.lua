-- Menu and documentation windows. blink draws the kind icons itself (Nerd Font, mono).
---@type genja.completion.Feature
return function(config)
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
