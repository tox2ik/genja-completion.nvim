-- File name completion while editing.
-- File names on the : command line are set up in cmdline.lua.
---@type genja.completion.Feature
return function(_, opts)
	table.insert(opts.sources, { name = 'path', group_index = 1 })
end
