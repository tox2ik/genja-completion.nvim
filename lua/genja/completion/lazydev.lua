-- Lua module names inside require('...'), from lazydev.nvim; above lua_ls's own items.
---@type genja.completion.Feature
return function(config)
	config.sources.per_filetype.lua = { inherit_defaults = true, 'lazydev' }
	config.sources.providers.lazydev = {
		name = 'LazyDev',
		module = 'lazydev.integrations.blink',
		score_offset = 100, -- lazydev's README value
	}
end
