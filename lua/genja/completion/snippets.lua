-- Snippet expansion with Neovim's built-in engine (vim.snippet), for the snippets
-- language servers send. No snippet plugin needed.
---@type genja.completion.Feature
return function(config)
	config.snippets = { preset = 'default' }
end
