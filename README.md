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
	event = { 'BufReadPre', 'BufNewFile', 'VeryLazy' },
	cmd = 'Mason',
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
	config = function(_, opts)
		require('genja.comps').setup(opts)
	end,
}
```

The entry point is `require('genja.comps')`, not `require('genja')`: a Neovim
config with its own `lua/genja/init.lua` would shadow a plugin `genja` module,
so `main = 'genja'` would run that file instead. With any other plugin manager,
put the plugin and its dependencies on the runtimepath and call
`require('genja.comps').setup({})` yourself.

Nothing else may call `cmp.setup()` or the LSP setup: no `config` on the
nvim-cmp and nvim-lspconfig specs. Without `require('genja.comps').setup()`,
nvim-cmp has no sources and the menu never opens while you type.

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

Other config can read the same settings, also before `setup()` has run (then
without the `setup()` opts):

```lua
require('genja.lsp').get()          -- the merged settings table
require('genja.lsp').enabled('php') -- true when PHP is turned on
```

## Languages

| key          | servers                  | extra tools       |
| ------------ | ------------------------ | ----------------- |
| `bash`       | bashls                   | shellcheck, shfmt |
| `c_cpp`      | clangd                   |                   |
| `go`         | gopls                    |                   |
| `lua`        | lua_ls                   |                   |
| `php`        | phpactor\*, laravel_ls   | phpstan, php-cs-fixer, phpcs, pint, php-debug-adapter |
| `powershell` | powershell_es            |                   |
| `python`     | pyrefly, ruff            |                   |
| `typescript` | tsc, eslint              |                   |

\* needs PHP 8.2+ on PATH. WordPress, Laravel and Symfony projects are detected;
see the top of `lua/genja/lang/php.lua` for which tools run where.
On Windows phpactor needs several workarounds, all automatic; see
`phpactor-windows.md`.
`lua/genja/lang/php.lua.intelephense` is the same setup on intelephense instead
(no Windows workarounds; licence optional). The loader skips it until it is
renamed to `php.lua`; see the top of the file.

### PHP: worth trying later

- [phptools.nvim](https://github.com/ccaglak/phptools.nvim): generates missing
  methods, classes, getters and setters, plus Laravel/Symfony-aware `gf`.
  Overlaps with phpactor's code actions; not tested together. Needs Neovim 0.12
  and ripgrep.

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

## Alternatives to nvim-cmp

Not used yet. Notes for a later comparison:

- **Built-in completion** (no plugin). On 0.11+, call
  `vim.lsp.completion.enable(true, client.id, buf, { autotrigger = true })` in
  an `LspAttach` autocommand. 0.12+ also has the `'autocomplete'` option, with
  sources set by `'complete'`. Fewer dependencies, but you get only LSP items
  in the plain popup menu. Buffer words, file paths, command-line completion
  and lazydev would have to be rebuilt on `'complete'`, and the
  `function(cmp, opts)` feature files would not apply.
- **[blink.cmp](https://github.com/saghen/blink.cmp)**. It is fast (a Rust
  fuzzy matcher), opens the menu as you type by default, has LSP, path,
  buffer, snippet and command-line sources built in, and lazydev ships a
  source for it. Switching means rewriting `lua/genja/completion/*`, because
  the feature files fill in an nvim-cmp `setup()` table. The LSP half only
  needs `require('blink.cmp').get_lsp_capabilities()` in place of
  `cmp_nvim_lsp`.

## Check that it works

See `validation-checklist.txt`.
