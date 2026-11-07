# genja-completion011.nvim

LSP + blink.cmp plugin for Neovim 0.11+, loaded from disk by the user's config
at `../../lua/lazyp/new/genja-comp011.lua` (lazy.nvim `dir =` spec). Config
root is `../..` (`%LOCALAPPDATA%\nvim`); plugin data is `%LOCALAPPDATA%\nvim-data`.
Read README.md for the user-facing picture.

## Layout

- `lua/genja/comps/init.lua`: entry point, `require('genja.comps').setup(opts)`.
- `lua/genja/lsp/init.lua`: loads enabled languages, calls `vim.lsp.config()`,
  mason-lspconfig `ensure_installed` + `automatic_enable`, installs tools.
- `lua/genja/lsp/config.lua`: defaults (`enabled` table, mason, diagnostics).
- `lua/genja/lsp/health.lua`: `:checkhealth genja.lsp`, three sections from the modules below. Each also has a case in the config's `tests/comps011` (group `mason`).
    - `lsp/installed.lua`: servers the enabled languages want (`require('genja.lsp').servers()`) whose cmd is not executable. mason-lspconfig only enables installed servers, so a missing one is otherwise silent. Case `mason: servers installed` (needs the child).
    - `lsp/venv.lua`: mason Python venvs whose base Python is gone (autotools_ls exit 103). Case `mason: python-venv`.
    - `lsp/shim.lua`: launchers in `mason/bin` whose target is gone. Case `mason: shims`.
    - `lsp/receipt.lua`: package folders without `mason-receipt.json`, an install or update cut off because a running server locked the old folder on Windows (mason counts the folder as installed). Case `mason: receipts`.
    - `venv.lua`, `shim.lua` and `receipt.lua` have no requires: the tests load them with `dofile`, without a child.
- Cut-off installs repair themselves: opening a file of a filetype in `REPAIR_ON_OPEN` (`lsp/init.lua`; today lua -> lua-language-server) stats the receipt; if missing, mason reinstalls with `force` in the background, then `vim.lsp.enable()` attaches the open buffers. Silent; only a failed repair notifies. Once per package per session; not with `g:genja_lsp_no_install`.
- lua_ls logs to `stdpath('log')/lua_ls` (`--logpath`), not into its install folder, so the open log doesn't block mason's update.
- `lua/genja/lang/<name>.lua`: one language each, returns
  `{ servers = { <lspconfig name> = overrides }, tools = { <mason pkg> } }`.
- `lua/genja/ft/<ft>.lua`: `vim.filetype.add()` specs.
- `ftplugin/*.lua`: diagnostics from a tool's own parser for languages with
  no server (make, gitconfig, sshconfig).
- `lua/genja/completion/*.lua`: one blink.cmp feature per file; `source.lua` builds the plugin's own sources from an `items(c)` function.

## Adding a language (e.g. json → jsonls)

1. Check the server's defaults in
   `%LOCALAPPDATA%\nvim-data\lazy\nvim-lspconfig\lsp\<server>.lua` and only
   override what differs. Check `nvim-data\mason\packages` for what is installed.
2. Create `lua/genja/lang/<name>.lua`, header comment in the style of the
   others (what the server does, runtime it needs on PATH, notes).
   Use lspconfig names under `servers`; Mason package names under `tools`.
3. Turn it on in all three places:
   - `lua/genja/lsp/config.lua`: `---@field <name>? boolean` and the `enabled` entry.
   - `../../lua/lazyp/new/genja-comp011.lua`: the `enabled` entry (the user's spec).
   - `README.md`: the options block and the Languages table (alphabetical).
4. Verify headless (below). Do not commit unless asked.

### Look at LazyVim and AstroNvim first

Before writing a language or its tooling (servers, Mason tools, linters, formatters, parsers, filetypes, test and
debug adapters), look at how the two big distributions set it up and use that as a starting point:

- LazyVim language extras (`:LazyExtras`, modular packs for Go, Docker, Helm, Terraform, Python and more):
  <https://www.lazyvim.org/extras/lang>; source `lua/lazyvim/plugins/extras/lang/<name>.lua` in the LazyVim repo.
- AstroCommunity packs (`astrocommunity/pack/<name>`): <https://github.com/AstroNvim/astrocommunity/tree/main/lua/astrocommunity/pack>.

Read what they pick: which server (and which of several), Mason packages, `root_markers`, filetype additions,
treesitter parsers, linters and formatters per filetype, settings that matter. Take the choices that fit, not the files.

- Don't copy their configs or depend on their plugin layout (`opts` merging, `LazyVim.*` helpers, community specs).
  genja is more modular: one `lang/<name>.lua` module per language, switched on per machine, with linters in
  `lua/genja/ext/lint.lua` and parsers in `lua/lazyp/my/load-treesitter.lua`.
- Note in the language module's header comment when a choice came from them or deliberately differs
  (e.g. "LazyVim uses X; here Y because ...").
- Same rule as the config's "survey first": use their idea only when it fits genja's mental model; check platform
  support (Windows) before adopting a tool, since both distributions assume Linux or macOS first.

## Verifying a server headless

Write a sample file (with a deliberate error) to the scratchpad, then:

```sh
nvim --headless "C:/path/to/file.ext" +'lua vim.defer_fn(function()
  print("ft="..vim.bo.filetype)
  for _,x in ipairs(vim.lsp.get_clients({bufnr=0})) do print("client", x.name) end
  for _,d in ipairs(vim.diagnostic.get(0)) do print(d.lnum+1, d.source, d.message) end
  vim.cmd("qa!") end, 10000)'
```

- Use forward-slash Windows paths (`cygpath -m`); `\\$var` in bash broke quoting.
- Wait ~10s: npm-based servers start slowly; at 8s jsonls had not attached yet.
- `vim.lsp.is_enabled('<server>')` and `vim.fn.exepath('<cmd>')` help when no
  client attaches. Compare with a known-good server (bashls on a `.sh` file).

## Conventions

- Spaces (4), single quotes, short comments that explain why.
- Commits: group by feature, no Claude/Co-Authored-By attribution.
- The user's config tree often has unrelated uncommitted changes; leave them alone.

## Decisions by feature

Unmarked bullets were stated by jaro. `(inferred)` marks Claude's reading of the
code or history: confirm or delete. `Hint:` is a working note for Claude.

### Running and testing

- Run the headless check above only when jaro asks; otherwise give the command.
- Publishing this plugin for other Windows users may be worth it later.
- Integration tests: the config's `tests/comps011/` (`make test D=comps011 G=<group>` in `tests/`): groups mason, lsp, ready, cmp, lint, fast, slow, gather, or a case name (lua_ls, typos ...); `pwsh -File tests/manual/measure-lua-ls.ps1` times lua_ls by hand; per-case timeouts and slow cutoffs, timings in `stdpath('state')`. They boot the real config with `g:genja_lsp_no_install` set, so mason installs nothing.

### Languages and local.lua

- A language is switched on per machine in the config's `lua/genja/lsp/local.lua`, not in the spec's `enabled` table.
- Languages without a server (gitconfig, sshconfig) still get a `lang/<name>.lua` with no servers, so they can be switched on and off.
- `require('genja.lsp').get()` and `.enabled(name)` expose the merged settings to other specs (used by `lazyp/debug/dap-php.lua`).
- `.servers()`: servers the enabled languages want, installed or not (`lsp/installed.lua`). `.languages()`: every language on or off, with its servers and tools (the config's `make status` in `tests/`).

### PHP

- phpactor only; intelephense's paid licence is deferred.
- `lang/` holds variants; the loader only reads `<name>.lua`, so switching is a rename:
  - `php.lua`: phpactor inside WSL (active). Distro in `local.lua` as `phpactor_wsl = { distro = ... }`; deps installed by `scripts/phpactor-wsl-install.sh` (apt or dnf). See `doc/phpactor-wsl.md`.
  - `php.lua.phpactor-windows`: native Windows phpactor with four workarounds (posix check, stubs, ProcessWrapper64.exe, TCP instead of stdin). See `doc/phpactor-windows.md`.
  - `php.lua.intelephense`: same roots and framework detection, for later.
- Root markers, first match wins: `.phproject`, `composer.json`, `.phpactor.json`/`.phpactor.yml`, `wp-config.php`, `artisan`, `.git`.
- WordPress, Laravel and Symfony are detected per root (stubs, ide-helper hint, Symfony extension).
- phpstan, not psalm. phpstan runs only with a `phpstan.neon(.dist)` in the root; php-cs-fixer only with a `.php-cs-fixer(.dist).php` / `.php_cs(.dist)`. Samples in `examples/php/`.
- Tests: overseer templates (`lua/overseer/template/user/php_test*.lua` in the config) and neotest. phptools.nvim is only a README note.
- `dap-php.lua`: the PHP adapter is set up inside the `enabled('php')` check, without an early return.
- `:PhpDocParams` (`lua/genja/php_docparams.lua`, treesitter) adds missing `@param` and `@return` tags to every function in the file or range.

### Lua, Go, Vimscript, JSON

- lua_ls: `root_dir` ignores the home folder (single-file mode instead), workspace preload limits, `callSnippet = 'Replace'`. README documents `'Both'` and `'Disable'`.
- lua_ls: env `GENJA_LUA_NO_LIB=1` loads no libraries: `workspace.library` empty (`lang/lua.lua`), lazydev `enabled` returns false (config's `lua/lazyp/langs-comps/lazydev.lua`). The config's `tests/Makefile` sets it by default (`?=`, exported); tests check that lua_ls works, not its libraries. `tests/manual/measure-lua-ls.ps1 -NoLib` times it.
- lua_ls: on a slow PC it flags `vim`, `require` etc. as undefined globals until the workspace is loaded. `on_attach` hides the buffer's diagnostics until lua_ls's first `LspProgress` 'end', or 10s at most.
- gopls: root is `go.work`, then `go.mod`, then `.git`; home folder ignored. Sample workspace in `examples/go/`.
- gopls: a `.go` file with no `go.mod`/`go.work` above it (single-file mode, code actions fail with "missing metadata") warns once per folder with the `go mod init` fix.
- gopls: on save, `source.organizeImports` (sync request, resolved when the edit is left out), then format. Opt out with `b:`/`g:go_format_on_save = v:false`.
- gopls: Nvim 0.11 APIs only; no `make_range_params` without position encoding, no `buf.execute_command`. No new plugins.
- gopls settings list only what differs from gopls defaults; check against `gopls api-json` when gopls updates (v0.23 dropped `completeUnimported` and `useany`).
- Code actions by kind live in the config's `lua/genja/map-lsp.lua`: `<leader>cq` quickfix, `<leader>ce` extract (needs a visual selection), `<leader>cr` rewrite, `<leader>cs` source; `<leader>cS` is search & replace.
- gopls code lenses are on for every gopls buffer (go.mod too): `vim.lsp.codelens.enable()` when it exists (0.12+), else `refresh()` on BufEnter/InsertLeave/BufWritePost. `<leader>cl` runs the lens on the cursor line.
- gopls `local` is filled in `before_init` from the root's go.work `use` modules, else its go.mod, unless already set. Set in place: `client.settings` is the same table, a replaced table never reaches gopls.
- vimls uses lspconfig defaults; jsonls only adds `validate`.

### Make, gitconfig, sshconfig diagnostics

- Diagnostics come from the tool's own parser in `ftplugin/<ft>.lua` (`make -n`, `git config --list`, `ssh -G`), and run only when that language is enabled.
- A missing tool warns once per session, prefixed with the script path relative to the config's parent.

### Filetypes

- One `lua/genja/ft/<filetype>.lua` per filetype, grouped by filetype rather than by extension, applied by `ft/init.lua`. A same-named file in the config replaces the plugin's.
- Personal mappings stay in the config (`yml` -> `yaml.ansible`).

### Completion features

- One blink.cmp feature per file in `lua/genja/completion/`, listed in the spec's `features`.
- blink.cmp replaced nvim-cmp in 2026-10 (tag `before-blink-2026-w44`). `<CR>` takes the preselected item (blink default); the old behaviour is commented out in `keymaps.lua`. Fuzzy matcher: the prebuilt Rust one (`prefer_rust_with_warning`).
- Own sources go through `source.register()`; blink requires `genja.completion.source` for each and picks it by `opts.id`.
- Tests: the config's `tests/completion/` (sources, cmdline, `<CR>`, ask popup) and the `cmp` group of `tests/comps011/`.
- Menu colours (`completion/appearance.lua`): the menu uses StatusLine; the selected item has Normal's text colour on that same background (no bar); typed letters are bold; kind icons and the PmenuExtra columns (detail, description, source) keep their text colour without the Pmenu background; the scrollbar thumb is the menu background, its track that background 60% darker. The documentation window uses the same colours and one space of padding left and right (`draw` pads the lines; blink has no padding option). Set again on `ColorScheme`.
- `gitignore` (file names in gitignore/gitattributes) is on by default.
- `gitcommit`: Conventional Commits types, scopes from `git log`, footers; only while genja-commit's mode is on (`b:genja_commit_conventional`). Types from `genja-commit.config` when loaded, else the standard list. Lives here next to the other sources, not in genja-commit.
- `dictionary` is for `text` and `markdown` only. Word source order: buffer `'dictionary'`, then `stdpath('data')/dict/en.txt`, then the shipped `dict/en.txt`; words from the spell `.add` file are always included.
- The dictionary index is built on the first text/markdown `FileType`: async read, then chunked indexing. Nothing is read at startup.
- `:DictionaryUpdatePopular` downloads into `stdpath('data')`; `make update-dict` refreshes the shipped list from the URL in `dictionary.lua`.
- Hint: the own sources need no extra plugins; keep it that way.
- `minuet` (minuet-ai.nvim; Codestral by default, ollama, Gemini, Claude and others in the spec) is a feature in the config's `lua/genja/completion/minuet.lua`, not here: it needs an extra plugin. Answers only `<M-y>` unless `:Minuet blink toggle`.
- Command line (`: / ?`, `completion/cmdline.lua`): `<Tab>` next, `<S-Tab>` previous (both open the menu), `<M-j>`/`<M-k>` next/previous while the menu is open, `<M-f>` previous too, `<M-w>` first item, `<M-s>` 3 down; `<Down>`/`<Up>` recall history (see below). `<M-x>` (like `<C-e>`) closes the menu.
    - Nothing is preselected (`completion.list.selection.preselect = false`): the first `<Tab>` on the open menu inserts item 1, `:term<Tab>` gives `:terminal`. The cmdline preset preselected item 1, so `<Tab>` went to item 2.
    - `<Up>`/`<Down>` are history, as in plain Vim (prefix filter included), even with the menu open. After `<Tab>`, `<S-Tab>` or one of the `<M-…>` walk keys they walk the menu, until another key is typed (`vim.on_key`) or a new command line starts. Tried out since 2026-10-31; ask before building on it.
