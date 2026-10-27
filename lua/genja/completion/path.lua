-- File name completion while editing.
-- File names on the : command line come from cmdline.lua.
---@type genja.completion.Feature
return function(config)
	table.insert(config.sources.default, 'path')
end
