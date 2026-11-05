-- PHP: phpactor running inside WSL, plus laravel-ls in Laravel projects.
-- Completion, hover, diagnostics, definition, references, rename, code actions
-- (import class, generate method, ...), implementation, type definition.
--
-- Windows: Neovim starts `wsl.exe [-d <distro>] -e phpactor language-server`
-- and talks to it over stdio. Paths in LSP messages are translated both ways:
--   C:\x, file:///C:/x                     -> /mnt/c/x, file:///mnt/c/x
--   \\wsl.localhost\<distro>\home\x        -> /home/x
--   file:///home/x (from phpactor)         -> file:////wsl.localhost/<distro>/home/x
-- Linux PHP has ext-posix and a working event loop on pipes, so none of the
-- native Windows workarounds (doc/phpactor-windows.md) are needed.
-- Other systems: plain phpactor from Mason, as lspconfig starts it.
--
-- Settings, in lua/genja/lsp/config.lua or local.lua:
--   phpactor_wsl = {
--     distro  = 'AlmaLinux-9',  -- wsl.exe -d; nil: the default distro (`wsl -l -v`)
--     install = true,           -- install PHP and phpactor in the distro when missing
--   }
-- :PhpactorWslInstall installs or updates PHP 8.2+ and phpactor in the distro
-- (apt on Debian/Ubuntu, dnf on AlmaLinux/Rocky/RHEL/Fedora), as root through
-- `wsl -u root`, so no sudo password is asked. See doc/phpactor-wsl.md.
--
-- Projects under /mnt/c are read through WSL's file bridge: indexing a big
-- project there is much slower than on the Linux side (\\wsl.localhost\...).
--
-- Frameworks, decided per project root when phpactor starts:
--   WordPress  wp-config.php or wp-load.php in the root or above it.
--              Indexes php-stubs/wordpress-stubs, downloaded once into
--              stdpath('data')/genja/php-stubs/wordpress. To refresh: delete it,
--              then `phpactor index:build --reset` in the project (inside WSL).
--   Laravel    artisan in the root. Facades and model magic need
--              barryvdh/laravel-ide-helper's _ide_helper*.php files.
--   Drupal     core/lib/Drupal.php in the root, web/ or docroot/. phpactor also indexes
--              .module .inc .install .theme .profile .engine (ft/drupal.lua maps them to php).
--   Symfony    bin/console or symfony.lock in the root. Turns on phpactor's Symfony
--              extension; run the app or `bin/console cache:warmup` once.
--
-- Tools phpactor runs itself, shown as diagnostics or used by vim.lsp.buf.format().
-- The project's vendor/bin copy wins over one on the distro's PATH. Windows' own
-- (Mason) copies can't run inside WSL and are not used there.
--   phpstan       only when the project has a phpstan config.
--   php-cs-fixer  only when the project has a php-cs-fixer config, never in
--                 WordPress or Laravel projects.
--   phpcs         WordPress only, when the project has a phpcs config or WPCS in vendor/.
--   pint          Laravel only, run on the file after each save (phpactor can't run it).

local SRC = 'lang/php.lua: '

local is_win = vim.fn.has('win32') == 1

local opts = vim.tbl_extend('force', { install = true }, require('genja.lsp').get().phpactor_wsl or {})

local stubs_dir = vim.fs.joinpath(vim.fn.stdpath('data'), 'genja', 'php-stubs', 'wordpress')
local stubs_file = vim.fs.joinpath(stubs_dir, 'wordpress-stubs.php')
local stubs_url = 'https://raw.githubusercontent.com/php-stubs/wordpress-stubs/master/wordpress-stubs.php'

local plugin_root = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(
	debug.getinfo(1, 'S').source:sub(2)))))
local install_script = vim.fs.joinpath(plugin_root, 'scripts', 'phpactor-wsl-install.sh')
-- PHP's own stubs, copied out of the .phar by the install script. Phpactor's
-- default reads them inside the .phar, and phar:// paths can't be opened from Windows.
local wsl_stubs = '/usr/local/lib/phpactor/phpstorm-stubs'

---wsl.exe with the configured distro, user and command.
---@param args string[]
---@param user? string
---@return string[]
local function wsl(args, user)
	local cmd = { 'wsl.exe' }
	if opts.distro then
		vim.list_extend(cmd, { '-d', opts.distro })
	end
	if user then
		vim.list_extend(cmd, { '-u', user })
	end
	return vim.list_extend(cmd, args)
end

-- wsl.exe writes its own messages in UTF-16 unless told otherwise.
local wsl_env = { WSL_UTF8 = '1' }

---@param s? string
local function clean(s)
	return ((s or ''):gsub('%z', ''):gsub('\r', ''))
end

---What the distro has, found once per session (and again after an install).
---@class genja.PhpWsl
---@field name string   $WSL_DISTRO_NAME, for \\wsl.localhost\<name>
---@field bins table<string, string>
---@type genja.PhpWsl?
local distro

local tool_names = { 'phpactor', 'php', 'phpstan', 'php-cs-fixer', 'phpcs', 'pint' }

---@return genja.PhpWsl?, string? error
local function probe()
	if distro then
		return distro
	end
	local script = 'echo "$WSL_DISTRO_NAME"; for t in ' .. table.concat(tool_names, ' ')
		.. '; do p=$(command -v "$t") && case "$p" in /mnt/*) ;; *) echo "$t=$p";; esac; done; [ -d ' .. wsl_stubs .. ' ] && echo stubs=' .. wsl_stubs .. '; true'
	local out = vim.system(wsl({ '-e', 'sh', '-c', script }), { env = wsl_env, text = true }):wait(60000)
	local stdout = clean(out.stdout)
	if out.code ~= 0 then
		return nil, ('wsl.exe exited with %s: %s'):format(out.code, clean(out.stderr) .. stdout)
	end
	local lines = vim.split(stdout, '\n', { trimempty = true })
	local found = { name = lines[1] or opts.distro or '', bins = {} }
	for i = 2, #lines do
		local name, path = lines[i]:match('^([^=]+)=(.+)$')
		if name then
			found.bins[name] = path
		end
	end
	distro = found
	return distro
end

-- Path and URI translation --------------------------------------------------

---Windows path or file URI -> WSL. Anything else comes back unchanged.
---@param s string
---@return string
local function to_wsl(s)
	if s:sub(1, 7) == 'file://' then
		local drive, rest = s:match('^file:///(%a):(.*)$')
		if not drive then
			drive, rest = s:match('^file:///(%a)%%3[aA](.*)$')
		end
		if drive then
			return 'file:///mnt/' .. drive:lower() .. rest
		end
		-- A buffer under \\wsl.localhost\<distro>\ or \\wsl$\<distro>\.
		if s:find('wsl', 1, true) then
			local path = vim.uri_decode(s):gsub('\\', '/'):match('^file:/*[wW][sS][lL][^/]*/[^/]+(/.*)$')
			if path then
				return vim.uri_from_fname(path)
			end
		end
		return s
	end
	local drive, rest = s:match('^(%a):[\\/](.*)$')
	if drive then
		return '/mnt/' .. drive:lower() .. '/' .. rest:gsub('\\', '/')
	end
	local path = s:match('^[\\/][\\/][wW][sS][lL][^\\/]*[\\/][^\\/]+([\\/].*)$')
	if path then
		return (path:gsub('\\', '/'))
	end
	return s
end

---WSL file URI -> one Neovim on Windows can open. Plain strings stay as they are.
---@param s string
---@return string
local function to_win(s)
	if s:sub(1, 8) ~= 'file:///' then
		return s
	end
	local drive, rest = s:match('^file:///mnt/(%a)(/.*)$')
	if not drive then
		drive, rest = s:match('^file:///mnt/(%a)$'), '/'
	end
	if drive then
		return 'file:///' .. drive:upper() .. ':' .. rest
	end
	return 'file:////wsl.localhost/' .. (distro and distro.name or '') .. s:sub(8)
end

-- Text that is never a path, even when it looks like one.
local text_keys = { text = true, newText = true, insertText = true, label = true, value = true, message = true }

---Copy of v with fn applied to every string value and table key.
---@param v any
---@param fn fun(s: string): string
---@param key? any
---@return any
local function map(v, fn, key)
	if type(v) == 'string' then
		return (text_keys[key] and v or fn(v))
	end
	if type(v) ~= 'table' then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[type(k) == 'string' and fn(k) or k] = map(x, fn, k)
	end
	-- Keeps vim.empty_dict() and json array markers.
	return setmetatable(out, getmetatable(v))
end

-- Install ---------------------------------------------------------------------

local installing = false

---Install or update PHP and phpactor in the distro, as root.
local function install()
	if installing then
		return
	end
	local f = io.open(install_script, 'rb')
	if not f then
		vim.notify(SRC .. 'missing ' .. install_script, vim.log.levels.ERROR)
		return
	end
	-- Fed through stdin, without CRs, so a CRLF checkout still runs.
	local script = f:read('*a'):gsub('\r', '')
	f:close()
	installing = true
	local log = vim.fs.joinpath(vim.fn.stdpath('log'), 'phpactor-wsl-install.log')
	local where = ''
	if opts.distro then
		where = ' (' .. opts.distro .. ')'
	end
	vim.notify(SRC .. 'installing PHP and phpactor in WSL' .. where .. ' ...')
	vim.system(wsl({ '-e', 'sh', '-s' }, 'root'), { stdin = script, env = wsl_env, text = true },
		vim.schedule_wrap(function(out)
			installing = false
			distro = nil
			local output = clean(out.stdout) .. clean(out.stderr)
			local lf = io.open(log, 'wb')
			if lf then
				lf:write(output)
				lf:close()
			end
			if out.code ~= 0 then
				local last = vim.split(vim.trim(output), '\n')
				vim.notify((SRC .. 'phpactor install in WSL failed (%s): %s\nFull log: %s'):format(
					out.code, last[#last] or '', log), vim.log.levels.ERROR)
				return
			end
			vim.notify(SRC .. 'phpactor installed in WSL, reindexing. Log: ' .. log)
			-- Stubs may have moved, and phpactor indexes them only on a project's
			-- first index: stop it, drop its cache (all projects), start it again.
			for _, client in ipairs(vim.lsp.get_clients({ name = 'phpactor' })) do
				client:stop(true)
			end
			vim.defer_fn(function()
				vim.system(wsl({ '-e', 'sh', '-c', 'rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/phpactor"' }), { env = wsl_env }):wait(30000)
				for _, buf in ipairs(vim.api.nvim_list_bufs()) do
					if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == 'php' then
						pcall(vim.api.nvim_exec_autocmds, 'FileType', { group = 'nvim.lsp.enable', buffer = buf, modeline = false })
					end
				end
			end, 1000)
		end))
end

if is_win then
	vim.api.nvim_create_user_command('PhpactorWslInstall', install, {
		desc = 'Install or update PHP and phpactor in WSL (genja)',
	})
end

-- Project settings --------------------------------------------------------------

---Download url to file unless it is already there. Blocks for a moment, on
---purpose: the file has to exist before phpactor starts.
---@param url string
---@param file string
---@param what string
local function download(url, file, what)
	if vim.uv.fs_stat(file) or vim.fn.executable('curl') == 0 then
		return
	end
	vim.fn.mkdir(vim.fs.dirname(file), 'p')
	vim.notify(SRC .. 'downloading ' .. what .. ' for phpactor ...')
	local part = file .. '.part'
	local out = vim.system({ 'curl', '-fsSL', '-o', part, url }):wait(60000)
	if out.code ~= 0 or not vim.uv.fs_rename(part, file) then
		vim.uv.fs_unlink(part)
		vim.notify(SRC .. 'could not download ' .. what .. ': ' .. (out.stderr or ''), vim.log.levels.WARN)
	end
end

---@param root string
---@param name string
local function has(root, name)
	return vim.uv.fs_stat(vim.fs.joinpath(root, name)) ~= nil
end

---@param root string
---@param names string[]
local function has_any(root, names)
	for _, name in ipairs(names) do
		if has(root, name) then
			return true
		end
	end
	return false
end

---Path to a tool as phpactor sees it: the project's vendor/bin first, then the
---distro's PATH on Windows, or PATH (Mason's bin is on it) elsewhere.
---@param root string
---@param name string
---@return string?
local function bin(root, name)
	local vendored = vim.fs.joinpath(root, 'vendor', 'bin', name)
	if vim.uv.fs_stat(vendored) then
		return (is_win and to_wsl(vendored) or vendored)
	end
	if is_win then
		return distro and distro.bins[name]
	end
	local found = vim.fn.exepath(name)
	return (found ~= '' and found or nil)
end

---@param root string
local function is_laravel(root)
	return has(root, 'artisan')
end

---Drupal 8+: core/lib/Drupal.php in the root, or in web/ or docroot/ (composer projects).
---@param root string
local function is_drupal(root)
	return has_any(root, { 'core/lib/Drupal.php', 'web/core/lib/Drupal.php', 'docroot/core/lib/Drupal.php' })
end

---Drupal's PHP files besides .php; ft/drupal.lua maps them to php inside a Drupal tree.
local DRUPAL_EXTENSIONS = { 'php', 'phar', 'module', 'inc', 'install', 'theme', 'profile', 'engine' }

local warned = {} ---@type table<string, true>

---Phpactor options for the project at root (a Windows path on Windows).
---@param root string
---@return table
local function project_options(root)
	local options = {}
	local wordpress = vim.fs.root(root, { 'wp-config.php', 'wp-load.php' }) ~= nil
	local laravel = is_laravel(root)

	-- A plugin or theme can have its own composer.json, so look above the root too.
	if is_win then
		options['indexer.stub_paths'] = { wsl_stubs }
	end
	if wordpress then
		download(stubs_url, stubs_file, 'WordPress stubs')
		if vim.uv.fs_stat(stubs_file) then
			-- This replaces phpactor's own stub path, so keep PHP's stubs.
			if is_win then
				options['indexer.stub_paths'] = { wsl_stubs, to_wsl(stubs_dir) }
			else
				options['indexer.stub_paths'] = { '%application_root%/vendor/jetbrains/phpstorm-stubs', stubs_dir }
			end
			-- The stubs are one 6 MB file; the default skips anything over 1 MB.
			options['indexer.max_filesize_to_index'] = 10000000
		end
	end

	if laravel and not has(root, '_ide_helper.php') and not warned[root] then
		warned[root] = true
		vim.notify(
			SRC .. 'Laravel without _ide_helper.php, facades will not resolve. In the project run:\n'
				.. '  composer require --dev barryvdh/laravel-ide-helper\n'
				.. '  php artisan ide-helper:generate && php artisan ide-helper:models -N\n'
				.. 'and add both artisan lines to composer.json "post-update-cmd" to keep them fresh.',
			vim.log.levels.INFO
		)
	end

	if has(root, 'bin/console') or has(root, 'symfony.lock') then
		options['symfony.enabled'] = true
	end

	-- hooks and procedural code live in .module, .inc, .install ... files, which phpactor skips by default
	if is_drupal(root) then
		options['indexer.supported_extensions'] = DRUPAL_EXTENSIONS
	end

	local phpstan = bin(root, 'phpstan')
	if phpstan and has_any(root, { 'phpstan.neon', 'phpstan.neon.dist', 'phpstan.dist.neon' }) then
		options['language_server_phpstan.enabled'] = true
		options['language_server_phpstan.bin'] = phpstan
	end

	local fixer = bin(root, 'php-cs-fixer')
	local fixer_config = { '.php-cs-fixer.php', '.php-cs-fixer.dist.php', '.php_cs', '.php_cs.dist' }
	if fixer and not wordpress and not laravel and has_any(root, fixer_config) then
		options['language_server_php_cs_fixer.enabled'] = true
		options['language_server_php_cs_fixer.bin'] = fixer
	end

	local phpcs = bin(root, 'phpcs')
	if phpcs and wordpress then
		if has_any(root, { 'phpcs.xml', '.phpcs.xml', 'phpcs.xml.dist', '.phpcs.xml.dist' }) then
			options['php_code_sniffer.enabled'] = true
		elseif has(root, 'vendor/wp-coding-standards/wpcs') then
			options['php_code_sniffer.enabled'] = true
			options['php_code_sniffer.args'] = { '--standard=WordPress' }
		end
		options['php_code_sniffer.bin'] = phpcs
	end

	return options
end

---Laravel: run pint on the file after each save, then reload the buffer.
---On Windows pint runs inside WSL too.
---@param root string
---@param buf integer
local function pint_on_save(root, buf)
	local pint = bin(root, 'pint')
	if not pint then
		return
	end
	vim.api.nvim_create_autocmd('BufWritePost', {
		buffer = buf,
		group = vim.api.nvim_create_augroup('genja_pint_' .. buf, { clear = true }),
		callback = function()
			local file = vim.api.nvim_buf_get_name(buf)
			local cmd = { pint, file }
			local cwd = root
			if is_win then
				cmd = wsl({ '--cd', to_wsl(root), '-e', pint, to_wsl(file) })
				cwd = nil
			end
			vim.system(cmd, { cwd = cwd, env = wsl_env, text = true }, vim.schedule_wrap(function(out)
				if out.code ~= 0 then
					local msg = (out.stderr ~= '' and out.stderr or out.stdout)
					vim.notify(SRC .. 'pint: ' .. clean(msg), vim.log.levels.WARN)
				elseif vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
					vim.api.nvim_buf_call(buf, function()
						local view = vim.fn.winsaveview()
						vim.cmd('silent! edit')
						vim.fn.winrestview(view)
					end)
				end
			end))
		end,
	})
end

-- Server ----------------------------------------------------------------------

---Windows: phpactor inside WSL over stdio, with every path in the messages
---translated. Elsewhere lspconfig's default cmd.
---@return (fun(dispatchers: vim.lsp.rpc.Dispatchers, config: vim.lsp.ClientConfig): vim.lsp.rpc.PublicClient)?
local function phpactor_cmd()
	if not is_win then
		return nil
	end
	return function(dispatchers, config)
		local found, err = probe()
		if not found then
			error('phpactor: cannot run WSL: ' .. err)
		end
		local phpactor = found.bins.phpactor
		if not phpactor or not found.bins.php or not found.bins.stubs then
			if opts.install then
				install()
				error('phpactor is not (fully) in WSL yet; installing it, it starts when done (:PhpactorWslInstall)')
			end
			error('phpactor, php or its stubs are not installed in WSL; run :PhpactorWslInstall')
		end

		local args = { '-e', phpactor, 'language-server' }
		if config.root_dir then
			table.insert(args, 1, to_wsl(config.root_dir))
			table.insert(args, 1, '--cd')
		end
		local rpc = vim.lsp.rpc.start(wsl(args), {
			notification = function(method, params)
				return dispatchers.notification(method, map(params, to_win))
			end,
			server_request = function(method, params)
				local result, rerr = dispatchers.server_request(method, map(params, to_win))
				return map(result, to_wsl), rerr
			end,
			on_exit = dispatchers.on_exit,
			on_error = dispatchers.on_error,
		}, { env = wsl_env })

		return {
			request = function(method, params, callback, notify_reply_callback)
				return rpc.request(method, map(params, to_wsl), function(rerr, result)
					callback(rerr, map(result, to_win))
				end, notify_reply_callback)
			end,
			notify = function(method, params)
				return rpc.notify(method, map(params, to_wsl))
			end,
			is_closing = rpc.is_closing,
			terminate = rpc.terminate,
		}
	end
end

-- Windows: Mason's Windows builds, which phpactor inside WSL can't run, are only
-- installed for the other systems.
local tools = { 'phpstan', 'php-cs-fixer', 'phpcs', 'pint', 'php-debug-adapter' }
if is_win then
	tools = { 'php-debug-adapter' }
end

---@type genja.Lang
return {
	servers = {
		phpactor = {
			-- lspconfig's markers plus WordPress and Laravel roots, which often have
			-- neither composer.json nor .git (a Local site's app/public, for one).
			-- .phproject: an empty file that marks a project root by hand; it wins over the rest.
			root_markers = { '.phproject', 'composer.json', '.phpactor.json', '.phpactor.yml', 'wp-config.php', 'artisan', '.git' },
			cmd = phpactor_cmd(),
			init_options = {
				-- Hints are sent; show them with vim.lsp.inlay_hint.enable() (<leader>tth here).
				['language_server_worse_reflection.inlay_hints.enable'] = true,
				['language_server_worse_reflection.inlay_hints.types'] = true,
				-- Also offer `use function` / `use const` imports for global names.
				['language_server_code_transform.import_globals'] = true,
			},
			before_init = function(params, config)
				if is_win then
					-- A Windows PID means nothing inside WSL; phpactor must not watch it.
					params.processId = vim.NIL
				end
				if config.root_dir then
					params.initializationOptions = vim.tbl_extend(
						'force',
						params.initializationOptions or {},
						project_options(config.root_dir)
					)
				end
			end,
			on_attach = function(client, buf)
				-- :PhpDocParams, @param tags for every function and method in the file.
				require('genja.php_docparams').attach(buf)
				if client.root_dir and is_laravel(client.root_dir) then
					pint_on_save(client.root_dir, buf)
				end
			end,
		},
		-- Routes, views, config and env keys. Starts only where there is an artisan file.
		laravel_ls = {
			workspace_required = true,
		},
	},
	tools = tools,
}
