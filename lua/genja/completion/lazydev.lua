-- Lua module names inside require('...'), from lazydev.nvim.
-- group_index 0 keeps lua_ls from also offering them.
---@type genja.completion.Feature
return function(_, opts)
	table.insert(opts.sources, { name = 'lazydev', group_index = 0 })
end
