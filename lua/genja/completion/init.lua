-- Completion entry point (nvim-cmp).
--
-- Each feature is one file in this directory that returns
--
--   function(cmp, opts) ... end
--
-- and adds its part to `opts`, the table that is finally passed to cmp.setup().
-- To add a feature, put lua/genja/completion/<name>.lua in your Neovim config
-- directory and list its name in setup({ completion = { features = ... } }).
-- A function in that list is called directly.

local M = {}

---Adds its part to `opts`, the table passed to cmp.setup().
---@alias genja.completion.Feature fun(cmp: table, opts: cmp.ConfigSchema)

---@class genja.completion.Opts
---@field features? (string|genja.completion.Feature)[] replaces M.features

M.features = {
	'keymaps', -- <Tab>, <CR>, ...
	'snippets', -- snippet expansion
	'lsp', -- language servers
	'path', -- file names
	'gitignore', -- file names in .gitignore / .gitattributes
	'sshconfig', -- options and values in ssh_config / sshd_config
	'dictionary', -- English words in text and markdown
	'buffer', -- words in the buffer
	'lazydev', -- require('...') module names in Lua
	'cmdline', -- : commands, :help topics, / search
	'appearance', -- windows and icons
}

---@param opts? genja.completion.Opts
function M.setup(opts)
	local cmp = require('cmp')
	local cmp_opts = { sources = {} }
	for _, feature in ipairs(opts and opts.features or M.features) do
		if type(feature) == 'string' then
			feature = require('genja.completion.' .. feature)
		end
		feature(cmp, cmp_opts)
	end
	cmp.setup(cmp_opts)
end

return M
