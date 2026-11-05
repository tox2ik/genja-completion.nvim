# genja-completion011.nvim

Language servers and completion for Neovim 0.11+, as one plugin with one
`setup()` call.

- **LSP**: one small file per language. Mason installs the servers and tools of
  the languages you turn on, and only those servers are enabled.
- **Completion**: blink.cmp, one small file per feature (keys, sources, command
  line, appearance). Its own sources (gitignore, sshconfig, gitcommit,
  dictionary) are built by `lua/genja/completion/source.lua`.

## Install

With lazy.nvim. The repo is `genja-completion.nvim`; `name` keeps the plugin's own name:

```lua
{
	'tox2ik/genja-completion.nvim',
	name = 'genja-completion011.nvim',
	event = { 'BufReadPre', 'BufNewFile', 'VeryLazy' },
	cmd = 'Mason',
	dependencies = {
		-- LSP
		'neovim/nvim-lspconfig',
		'mason-org/mason.nvim',
		'mason-org/mason-lspconfig.nvim', -- 2.x
		-- completion; a release tag, so blink downloads its prebuilt fuzzy matcher
		{ 'saghen/blink.cmp', version = '1.*' },
		-- optional
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

Nothing else may call `require('blink.cmp').setup()` or the LSP setup: no
`config` or `opts` on the blink.cmp and nvim-lspconfig specs.

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
			json = true,
			php = false,
			powershell = false,
			python = false,
			typescript = false,
		},
		mason = { ui = { border = 'double' } }, -- for require('mason').setup()
		diagnostics = { virtual_text = true, severity_sort = true }, -- for vim.diagnostic.config()
	},
	completion = {
		features = { 'keymaps', 'snippets', 'lsp', 'path', 'gitignore', 'sshconfig', 'gitcommit', 'dictionary', 'buffer', 'lazydev', 'cmdline', 'appearance' },
	},
})
```

- `lsp` is merged over the defaults, so `lsp = { enabled = { php = true } }`
  turns PHP on and leaves the rest as it is.
- `completion.features` replaces the default list. An entry is a file name in
  `lua/genja/completion/`, or a `function(config)` that adds to the table
  passed to `require('blink.cmp').setup()`.
- `<CR>` takes the preselected first item (blink's default). The old nvim-cmp
  behaviour (nothing preselected) is a commented-out line in `keymaps.lua`.
- `lsp = false` or `completion = false` skips that half.
- `lsp.diagnostics = false` leaves `vim.diagnostic.config()` alone.

`:lua =require('genja.lsp').config` shows the LSP settings in effect.

Other config can read the same settings, also before `setup()` has run (then
without the `setup()` opts):

```lua
require('genja.lsp').get()          -- the merged settings table
require('genja.lsp').enabled('php') -- true when PHP is turned on
```

`:EnableLang [-on|-off] [-save] <lang>` (or `require('genja.lsp').set_lang(name, on, save)`)
turns a language on or off for the session. On: its servers are configured,
installed when missing, and attach to open buffers. Off: its servers stop,
unless another language that is on uses them. `-save` also writes
`<lang> = true|false` into the `enabled` table of `local.lua` (created if
missing); comments are kept, and nothing is written unless the edited file
loads and gives that value. Make, gitconfig and sshconfig diagnostics
start in buffers opened afterwards (or after `:e`).

## Languages

| key          | servers                  | extra tools       |
| ------------ | ------------------------ | ----------------- |
| `bash`       | bashls                   | shellcheck, shfmt |
| `c_cpp`      | clangd                   |                   |
| `gitconfig`  | none\*\*\*                 |                   |
| `go`         | gopls (see [Go](#go))    |                   |
| `json`       | jsonls                   |                   |
| `lua`        | lua_ls                   |                   |
| `make`       | autotools_ls\*\*         | make parse errors\*\*\* |
| `php`        | phpactor\*, laravel_ls   | phpstan, php-cs-fixer, phpcs, pint, php-debug-adapter |
| `powershell` | powershell_es            |                   |
| `python`     | pyrefly, ruff            |                   |
| `sshconfig`  | none\*\*\*                 | ssh parse errors\*\*\* |
| `typescript` | tsc, eslint              |                   |
| `vim`        | vimls                    |                   |

\* needs PHP 8.2+ on PATH. WordPress, Laravel and Symfony projects are detected;
see the top of `lua/genja/lang/php.lua` for which tools run where.
On Windows phpactor needs several workarounds, all automatic; see
`phpactor-windows.md`.
`lua/genja/lang/php.lua.intelephense` is the same setup on intelephense instead
(no Windows workarounds; licence optional). The loader skips it until it is
renamed to `php.lua`; see the top of the file.

\*\* Makefile, Automake and configure.ac; needs Python on PATH (pip package).

\*\*\* Diagnostics from the tool itself, checked on open and on save:
`ftplugin/make.lua` runs `make -n` (GNU make on PATH), `ftplugin/gitconfig.lua`
runs `git config --list` (git on PATH), `ftplugin/sshconfig.lua` runs
`ssh -G -F <file>` (OpenSSH on PATH; `Match exec` commands in the file still
run). Each runs only while its language is enabled.

### Filetypes

`lua/genja/ft/<filetype>.lua` returns a spec for `vim.filetype.add()`; all of
them are added by `setup()`, also with `lsp = false`. Shipped: `gitconfig`
(`*.gitconfig`, `.gitconfig.local`, `.gitconfig-work`), `gitignore`
(`.gitignore_global`, `.ignore`, `.rgignore`, `.fdignore`) and `gitattributes`
(`.gitattributes_global`), `sshconfig` (`~/.ssh/config.d/*`, `~/.ssh/config.local`,
`ssh_config.d/*`) and `sshdconfig` (`sshd_config.d/*`). As with languages, a file with the same name in your
Neovim config directory replaces the shipped one, and a new name adds a
filetype:

```lua
-- ~/.config/nvim/lua/genja/ft/yaml.lua
return { extension = { yml = 'yaml.ansible' } }
```

### PHP: worth trying later

- [phptools.nvim](https://github.com/ccaglak/phptools.nvim): generates missing
  methods, classes, getters and setters, plus Laravel/Symfony-aware `gf`.
  Overlaps with phpactor's code actions; not tested together. Needs Neovim 0.12
  and ripgrep.

### Function call snippets

Picking a function from the menu inserts `name(arg1, arg2)` with the cursor on
the first argument; `<Tab>` jumps to the next. Set per server:

| server | setting (in `lang/<name>.lua`)          | values |
| ------ | --------------------------------------- | ------ |
| lua_ls | `Lua.completion.callSnippet`            | `'Replace'` (set here): the snippet only<br>`'Both'`: the plain name and the snippet as two menu entries<br>`'Disable'`: name only (lua_ls default) |
| gopls  | `gopls.usePlaceholders`                 | `true` (set here): with argument placeholders<br>`false`: `name()` only, cursor inside the parentheses |

### lua_ls without libraries

lua_ls answers completion requests with an empty list until it has indexed its
libraries: the Neovim runtime and required plugins (lazydev.nvim) and
`workspace.library` in `lang/lua.lua`. That takes 5-7 s on a laptop CPU.
Set the environment variable `GENJA_LUA_NO_LIB=1` before starting Neovim to
skip them: lazydev turns off, `workspace.library` stays empty, and lua_ls
answers much sooner. Locals and the Lua standard library still complete;
`vim.*` and plugin types don't. The config's `tests/Makefile` sets it by default.

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

## SSH config

In `sshconfig` (`~/.ssh/config`, `ssh_config`, `config.d/*`) and `sshdconfig`
(`sshd_config`) buffers the `sshconfig` feature offers the option names at the
start of a line and, after an option, its fixed values (`yes`/`no`, `LogLevel`,
`StrictHostKeyChecking`, `Match` criteria, ...). `Ciphers`, `MACs`,
`KexAlgorithms` and the key algorithm lists get what `ssh -Q` reports on this
machine. Paths (`IdentityFile ~/...`) come from the path source.

There is no language server for ssh config. With `lsp.enabled.sshconfig`
(default on), `ssh -G` checks the client config on open and on save; sshd_config
is not checked (`sshd -t` needs the host keys). Treesitter: `ssh_config` parser
for `sshconfig`; `sshdconfig` keeps vim's syntax file.

## Commit messages

In `gitcommit` buffers the `gitcommit` feature offers Conventional Commits
parts: the types (`feat`, `fix`, ...) at the start of the summary line, scopes
used before in `git log` after `type(` (most used first), and footers
(`BREAKING CHANGE:`, `Refs: #`, `Co-authored-by:`) at the start of body lines.
Only while genja-commit.nvim's Conventional Commits mode is on for the repo;
its `conventional_types` option sets the type list.

## Go

Needs Go on PATH: mason builds gopls with `go install`. Everything below is in
`lua/genja/lang/go.lua`, which sets only what differs from the gopls defaults
(checked against `gopls api-json`, gopls v0.23).

- **Root**: `go.work`, then `go.mod`, then `.git`; never the home folder. Files
  in the module cache or GOROOT (reached through go-to-definition) reuse the
  running gopls. A two-module sample workspace is in `examples/go/`.
- **No go.mod**: a `.go` file with no `go.mod` or `go.work` above it puts gopls
  in single-file mode, where code actions fail with "missing metadata". A
  warning names the folder and the fix (`go mod init <name>`), once per folder.
- **On save**: organize imports, then format. Off for one buffer with
  `vim.b.go_format_on_save = false`, everywhere with `vim.g.go_format_on_save = false`.
- **Import groups**: gopls' `local` is set to the workspace's module paths, read
  from `go.work`/`go.mod`, so imports of your own modules get a group of their
  own. A value you set yourself wins:
  `vim.lsp.config('gopls', { settings = { gopls = { ['local'] = 'example.com/x' } } })`.
- **Code lenses**: lines gopls shows above code, such as "run test" above a
  `TestXxx` function, and "tidy" or "upgrade dependency" in `go.mod`. On in
  every gopls buffer; run the one on the cursor line with `vim.lsp.codelens.run()`.
- **Checks**: staticcheck is on, and many of its findings come with quickfixes.
  The `shadow` analyzer stays off (noisy with `err :=`).
- **Inlay hints**: every gopls hint is turned on, shown only while inlay hints
  are (`vim.lsp.inlay_hint.enable()`).

### Code actions by kind

`vim.lsp.buf.code_action()` lists everything. Filtering by kind gives shorter
menus, and in visual mode the selection is sent as the range:

| kind               | where            | gopls offers |
| ------------------ | ---------------- | ------------ |
| `quickfix`         | cursor           | fixes for the diagnostic under the cursor |
| `refactor.extract` | visual selection | statements → function or method; one expression → variable or constant |
| `refactor.rewrite` | cursor           | fill struct, fill switch, invert if, split/join lines, remove unused parameter |
| `refactor.inline`  | cursor on a call | inline the call |
| `source`           | anywhere         | organize imports, browse docs, add a test |

The plugin maps no keys. For example:

```lua
vim.keymap.set({ 'n', 'v' }, '<leader>ce', function()
	vim.lsp.buf.code_action({ context = { only = { 'refactor.extract' } } })
end, { desc = 'Code action: extract' })
```

A kind also matches its subkinds: `refactor.extract` includes
`refactor.extract.function`.

## Dictionary words

In `text` (.txt) and `markdown` buffers the `dictionary` feature offers
English words after three letters, next to words from the buffer. A
capitalised prefix gets capitalised words. Words come from, in this order:

1. the buffer's `'dictionary'` option, when it is set
2. `stdpath('data')/dict/en.txt`, once downloaded (see below)
3. `dict/en.txt` on the runtimepath; the plugin ships one, and one in your
   Neovim config directory replaces it

plus the words you added with `zg` (the files in `'spellfile'`, or
`spell/*.add`). New `zg` words show up without a restart.

The shipped list is `popular.txt` from
[dolph/dictionary](https://github.com/dolph/dictionary): about 25k common
English words, built from the public-domain ENABLE list and Wiktionary word
frequencies.

`:DictionaryUpdatePopular` downloads the current `popular.txt` with curl to
`stdpath('data')/dict/en.txt`. Nothing is downloaded otherwise.

`:checkhealth blink.cmp` lists the sources active in the current buffer;
in a text or markdown file `dictionary` should be among them.

## LSP check

`:CheckHealthSimpleLsp` opens a float that confirms a language server is
attached to the current buffer. It shows PASS or FAIL, the file and its
detected language, and each server with its languages and workspace folders.
`q` or `<Esc>` closes it. The command is always defined; there is no option to
turn it off.

The same action is available as `<Plug>CheckHealthSimpleLsp`. No key is bound
by default; bind one yourself, for example:

```lua
vim.keymap.set('n', '<leader>ch', '<Plug>CheckHealthSimpleLsp', { desc = 'LSP check' })
```

The code is in `lua/genja/lsp/check.lua`.

### Health check: missing and broken servers

`:checkhealth genja.lsp` checks three ways a server or tool silently never
starts, and names the fix for each:

- **Servers not installed.** mason-lspconfig enables a server only once it is
  installed, so a missing server of an enabled language just never attaches.
  The check lists every server the enabled languages want and whether its
  command is executable (`lua/genja/lsp/installed.lua`).
- **Python tools whose Python is gone.** mason installs Python tools
  (autotools-language-server, gitlint, yamllint ...) into a venv per package:
  `mason/packages/<package>/venv/`. Its `pyvenv.cfg` names the Python it was
  built from (`home =`). When that Python is uninstalled or moved, the tool
  exits at once (code 103 on Windows). Fix: `:MasonInstall --force <package>`
  (`lua/genja/lsp/venv.lua`).
- **Launchers whose target is gone.** Every tool has a launcher in
  `mason/bin` (a `.cmd` file on Windows, a symlink elsewhere). One left behind
  by an interrupted uninstall or update still counts as executable. Launchers
  from an older mason name their target by full path; they work, but break if
  the mason folder moves, so they show as a warning
  (`lua/genja/lsp/shim.lua`).

## Alternatives

nvim-cmp was used until 2026-10 (git tag `before-blink-2026-w44`). Not used:

- **Built-in completion** (no plugin). On 0.11+, call
  `vim.lsp.completion.enable(true, client.id, buf, { autotrigger = true })` in
  an `LspAttach` autocommand. 0.12+ also has the `'autocomplete'` option, with
  sources set by `'complete'`. Fewer dependencies, but you get only LSP items
  in the plain popup menu. Buffer words, file paths, command-line completion
  and lazydev would have to be rebuilt on `'complete'`, and the
  `function(config)` feature files would not apply.

## Check that it works

See `validation-checklist.txt`.
