-- Words from the current buffer. Shown only when lsp and path have nothing.
---@type genja.completion.Feature
return function(_, opts)
	table.insert(opts.sources, { name = 'buffer', group_index = 2 })
end
