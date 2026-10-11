-- Snippet expansion with Neovim's built-in engine. No snippet plugin needed
-- for the snippets that language servers send.
---@type genja.completion.Feature
return function(_, opts)
	opts.snippet = {
		expand = function(args)
			vim.snippet.expand(args.body)
		end,
	}
end
