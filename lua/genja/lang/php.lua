-- PHP: phpactor only.
-- Completion, hover, diagnostics, definition, references, rename, code actions
-- (import class, generate method, ...), implementation, type definition.
-- Needs PHP 8.2+ on PATH; Mason installs phpactor.phar and a wrapper that runs it with `php`.
--
-- Frameworks, decided per project root when phpactor starts:
--   WordPress  wp-config.php or wp-load.php in the root or above it.
--              Indexes php-stubs/wordpress-stubs, downloaded once into
--              stdpath('data')/genja/php-stubs/wordpress. To refresh: delete it,
--              then `phpactor index:build --reset` in the project.
--   Laravel    artisan in the root. Phpactor reads vendor/ on its own; facades and
--              model magic need barryvdh/laravel-ide-helper's _ide_helper*.php files,
--              which are indexed like any other project file.
--   Symfony    bin/console or symfony.lock in the root. Turns on phpactor's Symfony
--              extension (container services). It reads the container dump in var/cache/dev,
--              so run the app or `bin/console cache:warmup` once.

local stubs_dir = vim.fs.joinpath(vim.fn.stdpath('data'), 'genja', 'php-stubs', 'wordpress')
local stubs_file = vim.fs.joinpath(stubs_dir, 'wordpress-stubs.php')
local stubs_url = 'https://raw.githubusercontent.com/php-stubs/wordpress-stubs/master/wordpress-stubs.php'

---Download the WordPress stubs once. This blocks for a moment, on purpose:
---phpactor indexes stub_paths only on its first index of a project, so the
---file has to be there before phpactor starts.
local function fetch_wordpress_stubs()
	if vim.uv.fs_stat(stubs_file) or vim.fn.executable('curl') == 0 then
		return
	end
	vim.fn.mkdir(stubs_dir, 'p')
	vim.notify('genja: downloading WordPress stubs for phpactor ...')
	local part = stubs_file .. '.part'
	local out = vim.system({ 'curl', '-fsSL', '-o', part, stubs_url }):wait(60000)
	if out.code ~= 0 or not vim.uv.fs_rename(part, stubs_file) then
		vim.uv.fs_unlink(part)
		vim.notify('genja: could not download WordPress stubs: ' .. (out.stderr or ''), vim.log.levels.WARN)
	end
end

---@param root string
---@param name string
local function has(root, name)
	return vim.uv.fs_stat(vim.fs.joinpath(root, name)) ~= nil
end

local warned = {} ---@type table<string, true>

---Phpactor options for the frameworks found at root.
---@param root string
---@return table
local function framework_options(root)
	local options = {}

	-- A plugin or theme can have its own composer.json, so look above the root too.
	if vim.fs.root(root, { 'wp-config.php', 'wp-load.php' }) then
		fetch_wordpress_stubs()
		if vim.uv.fs_stat(stubs_file) then
			options['indexer.stub_paths'] = { stubs_dir }
			-- The stubs are one 6 MB file; the default skips anything over 1 MB.
			options['indexer.max_filesize_to_index'] = 10000000
		end
	end

	if has(root, 'artisan') and not has(root, '_ide_helper.php') and not warned[root] then
		warned[root] = true
		vim.notify(
			'genja: Laravel without _ide_helper.php, facades will not resolve. In the project run:\n'
				.. '  composer require --dev barryvdh/laravel-ide-helper\n'
				.. '  php artisan ide-helper:generate && php artisan ide-helper:models -N',
			vim.log.levels.INFO
		)
	end

	if has(root, 'bin/console') or has(root, 'symfony.lock') then
		options['symfony.enabled'] = true
	end

	return options
end

return {
	servers = {
		phpactor = {
			-- lspconfig's markers plus WordPress and Laravel roots, which often have
			-- neither composer.json nor .git (a Local site's app/public, for one).
			root_markers = { 'composer.json', '.phpactor.json', '.phpactor.yml', 'wp-config.php', 'artisan', '.git' },
			before_init = function(params, config)
				if config.root_dir then
					params.initializationOptions = vim.tbl_extend(
						'force',
						params.initializationOptions or {},
						framework_options(config.root_dir)
					)
				end
			end,
		},
	},
}
