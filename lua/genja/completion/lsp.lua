-- Completion from language servers.
-- The matching client capabilities are set in lua/genja/lsp/init.lua.
---@type genja.completion.Feature
return function(_, opts)
	table.insert(opts.sources, { name = 'nvim_lsp', group_index = 1 })
end
