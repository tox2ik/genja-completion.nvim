-- Command-line completion.
return function(cmp)
	-- `:` Ex commands and their arguments. This also covers :help topics,
	-- because cmp-cmdline asks Neovim for the same candidates <Tab> would give.
	cmp.setup.cmdline(':', {
		mapping = cmp.mapping.preset.cmdline(),
		sources = cmp.config.sources({
			{ name = 'path' },
		}, {
			{ name = 'cmdline', option = { ignore_cmds = { 'Man', '!', 'w' } } },
		}),
	})

	-- `/` and `?` search: words from the buffer.
	cmp.setup.cmdline({ '/', '?' }, {
		mapping = cmp.mapping.preset.cmdline(),
		sources = {
			{ name = 'buffer' },
		},
	})
end
