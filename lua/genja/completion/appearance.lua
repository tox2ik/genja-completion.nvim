-- Menu and documentation windows, and the kind icons.
return function(_, opts)
	opts.window = {
		completion = {
			side_padding = 1,
			scrolloff = 2,
			winblend = 4,
			winhighlight = 'NormalFloat:StatusLine,FloatBorder:NormalFloat',
		},
		documentation = {
			winblend = 4,
		},
	}

	opts.formatting = {
		fields = { 'kind', 'abbr', 'menu' },
		expandable_indicator = true,
	}

	local has_lspkind, lspkind = pcall(require, 'lspkind')
	if has_lspkind then
		opts.formatting.format = lspkind.cmp_format({
			mode = 'symbol',
			maxwidth = function()
				return math.floor(0.96 * vim.o.columns)
			end,
			ellipsis_char = '…',
			show_labelDetails = true,
		})
	end
end
