# genja-completion011.nvim

Language servers and completion for Neovim 0.11+, as one plugin with one
`setup()` call.

- **LSP**: one small file per language. Mason installs the servers and tools of
  the languages you turn on, and only those servers are enabled.
- **Completion**: nvim-cmp, one small file per feature (keys, sources, command
  line, appearance).

## Install

With lazy.nvim. While the plugin lives on disk, point `dir` at it:

```lua
{
	dir = '~/path/to/genja-completion011.nvim', -- later: 'you/genja-completion011.nvim'
	main = 'genja',
	dependencies = {
		-- LSP
		'neovim/nvim-lspconfig',
		'mason-org/mason.nvim',
		'mason-org/mason-lspconfig.nvim', -- 2.x
		-- completion
		'hrsh7th/nvim-cmp',
		'hrsh7th/cmp-nvim-lsp',
		'hrsh7th/cmp-buffer',
		'hrsh7th/cmp-path',
		'hrsh7th/cmp-cmdline',
		-- optional
		'onsails/lspkind.nvim', -- kind icons in the menu
		{ 'folke/lazydev.nvim', ft = 'lua', opts = {} }, -- Neovim API for lua_ls
	},
	opts = {},
}
```

`opts = {}` makes lazy.nvim call `require('genja').setup({})`. With any other
plugin manager, put the plugin and its dependencies on the runtimepath and make
that call yourself.

## Options

Everything is optional. These are the defaults:

```lua
require('genja').setup({
	lsp = {
		-- Keys are file names in lua/genja/lang/ without ".lua".
		enabled = {
			bash = true,
			lua = true,
			c_cpp = false,
			go = false,
			php = false,
			powershell = false,
			python = false,
			typescript = false,
		},
		mason = { ui = { border = 'double' } }, -- for require('mason').setup()
		diagnostics = { virtual_text = true, severity_sort = true }, -- for vim.diagnostic.config()
	},
	completion = {
		features = { 'keymaps', 'snippets', 'lsp', 'path', 'buffer', 'lazydev', 'cmdline', 'appearance' },
	},
})
```

- `lsp` is merged over the defaults, so `lsp = { enabled = { php = true } }`
  turns PHP on and leaves the rest as it is.
- `completion.features` replaces the default list. An entry is a file name in
  `lua/genja/completion/`, or a `function(cmp, opts)` that adds to the table
  passed to `cmp.setup()`.
- `lsp = false` or `completion = false` skips that half.
- `lsp.diagnostics = false` leaves `vim.diagnostic.config()` alone.

`:lua =require('genja.lsp').config` shows the LSP settings in effect.

## Languages

| key          | servers                  | extra tools       |
| ------------ | ------------------------ | ----------------- |
| `bash`       | bashls                   | shellcheck, shfmt |
| `c_cpp`      | clangd                   |                   |
| `go`         | gopls                    |                   |
| `lua`        | lua_ls                   |                   |
| `php`        | intelephense, phpactor\* |                   |
| `powershell` | powershell_es            |                   |
| `python`     | pyrefly, ruff            |                   |
| `typescript` | tsc, eslint              |                   |

\* not on Windows.

### Add or change a language

Language files are looked up on the runtimepath, so they do not have to live in
this plugin. Put one in your Neovim config directory:

```lua
-- ~/.config/nvim/lua/genja/lang/yaml.lua
return {
	servers = { yamlls = { settings = { yaml = { keyOrdering = false } } } }, -- lspconfig name = overrides
	tools = { 'yamllint' }, -- mason package names
}
```

and turn it on with `lsp = { enabled = { yaml = true } }`. A file with the same
name as one shipped here replaces it.

### Per-machine overrides

`lua/genja/lsp/local.lua` in your Neovim config directory has the same shape as
`lsp`, is merged last, and is meant to stay out of git:

```lua
-- ~/.config/nvim/lua/genja/lsp/local.lua
return { enabled = { php = true, powershell = false } }
```

## Diagnostics

The default shows inline virtual text for every diagnostic. That gets noisy
with two servers on one buffer (Pyrefly and Ruff, say). Two quieter settings
for `lsp.diagnostics`:

```lua
-- shorter virtual text, source shown only when there is more than one
{
	signs = true,
	underline = true,
	severity_sort = true,
	virtual_text = { spacing = 2, source = 'if_many' },
	float = { border = 'rounded', source = 'if_many' },
}

-- nothing inline, full text under the current line only
{
	virtual_text = false,
	virtual_lines = { current_line = true },
}
```

## Check that it works

See `validation-checklist.txt`.
