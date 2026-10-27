-- Words from the current buffer. blink shows them only when lsp and path have
-- nothing (their default `fallbacks`).
---@type genja.completion.Feature
return function(config)
	table.insert(config.sources.default, 'buffer')
end
