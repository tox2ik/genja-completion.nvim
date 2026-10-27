-- Completion entry point (blink.cmp).
--
-- Each feature is one file in this directory that returns
--
--   function(config) ... end
--
-- and adds its part to `config`, the table that is finally passed to
-- require('blink.cmp').setup(). To add a feature, put lua/genja/completion/<name>.lua
-- in your Neovim config directory and list its name in
-- setup({ completion = { features = ... } }). A function in that list is called directly.
-- The plugin's own sources (gitignore, sshconfig, gitcommit, dictionary) are built by
-- source.lua.

local M = {}

---Adds its part to `config`, the table passed to require('blink.cmp').setup().
---@alias genja.completion.Feature fun(config: blink.cmp.Config)

---@class genja.completion.Opts
---@field features? (string|genja.completion.Feature)[] replaces M.features

M.features = {
	'keymaps', -- <Tab>, <CR>, ...
	'snippets', -- snippet expansion
	'lsp', -- language servers
	'path', -- file names
	'buffer', -- words in the buffer
	'gitignore', -- file names in .gitignore / .gitattributes
	'sshconfig', -- options and values in ssh_config / sshd_config
	'gitcommit', -- Conventional Commits types, scopes, footers (with genja-commit)
	'dictionary', -- English words in text and markdown
	'lazydev', -- require('...') module names in Lua
	'cmdline', -- : commands, :help topics, / search
	'appearance', -- windows and icons
}

---@param opts? genja.completion.Opts
function M.setup(opts)
	---@type blink.cmp.Config
	local config = {
		keymap = {},
		completion = {},
		cmdline = {},
		sources = { default = {}, per_filetype = {}, providers = {} },
		-- the prebuilt Rust matcher (blink downloads it for its release tag); Lua if that fails
		fuzzy = { implementation = 'prefer_rust_with_warning' },
	}
	for _, feature in ipairs(opts and opts.features or M.features) do
		if type(feature) == 'string' then
			feature = require('genja.completion.' .. feature)
		end
		feature(config)
	end
	require('blink.cmp').setup(config)
end

return M
