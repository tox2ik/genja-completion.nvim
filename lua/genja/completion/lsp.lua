-- Completion from language servers.
-- The client capabilities are set in lua/genja/lsp/init.lua.
---@type genja.completion.Feature
return function(config)
	table.insert(config.sources.default, 'lsp')
end
