# phpactor on Windows

Phpactor has no official Windows support (no Windows CI; see
[phpactor#2551](https://github.com/phpactor/phpactor/issues/2551)). Mason's
`phpactor.phar` fails on native Windows PHP in four ways. genja works around all
four; nothing in the `.phar` itself is changed, so a Mason update keeps working
unless the patched code moves (the wrapper then prints a warning to stderr).

Check it all with:

```powershell
nvim --clean --headless -l <plugin>\scripts\phpactor-check.lua [project dir]
```

It starts phpactor with genja's own settings and reports files, process start,
diagnostics and `array_` completion. Pass an already indexed project: a fresh
temp project has to index the PHP stubs first, which takes a minute or two.

## 1. It refuses to start: "requires extension posix"

Windows PHP has no ext-posix. The `.phar` checks for it twice: Box's requirement
checker, then `bin/phpactor`. Phpactor only calls `posix_*` behind
`function_exists()` or on Unix-only paths, so the checks can be skipped.

**Fix:** `scripts/phpactor-nocheck.php` loads the `.phar` and runs phpactor's
Application directly, without either check. `php.lua` starts phpactor as
`php phpactor-nocheck.php <phar> language-server`. The wrapper also tells
phpactor that it is its binary, so index workers come back through it.

## 2. No completion for built-in functions (`array_map`, ...)

Phpactor gives stub paths the include pattern `/**/*` without the drive letter
(project paths get the project root prepended). No `C:/...` file matches, so the
PHP stubs are never indexed. `index:query array_map` showed an empty `Path:`.

**Fix:** on Windows the wrapper loads `Phpactor\Filesystem\Domain\FileList`
from the `.phar` with that catch-all pattern matching every path, before the
autoloader would load the original. It also copies the stubs out of the `.phar`
next to it (`mason/packages/phpactor/phpstorm-stubs`, refreshed per phpactor
version) and indexes that copy, so go-to-definition can open them.

After changing stubs: `phpactor index:build --reset` in the project.

## 3. Diagnostic provider "php" errored: CreateProcess failed, error code 2

amphp/process (phpactor's process library) starts programs on Windows through
`ProcessWrapper64.exe`, which the `.phar` leaves out. That breaks `php -l`,
phpstan, php-cs-fixer and phpcs.

**Fix:** `php.lua` downloads `ProcessWrapper64.exe` once from amphp/process,
pinned to the version inside the `.phar` (v1.1.9), into
`mason/packages/phpactor/`. A Mason reinstall wipes it and it comes back on the
next start. The wrapper points amphp's Windows runner at that copy.

## 4. No diagnostics, completion stalls

Over stdio, phpactor's event loop waits on the stdin pipe and its timers never
fire until Neovim sends the next message. Diagnostics (which wait 1 s after a
change), indexing and completion only moved while typing; the check showed
diagnostics arriving only when the next request came in, 60 s later.

**Fix:** on Windows `php.lua` starts phpactor as a TCP server
(`language-server --address=127.0.0.1:0 -vv`), reads the port from its
"Listening on" line, and connects with `vim.lsp.rpc.connect`. The server is
stopped with the client and on `VimLeavePre`. Its stderr goes to the LSP log.
`GENJA_PHPACTOR_TCP=1` does the same on Linux or macOS, for testing.

Also off on Windows: `language_server.diagnostic_outsource` and
`code_action_outsource`, which would start a second phpactor process.

## 5. Provider ... PhpCsFixerDiagnosticsProvider (php-cs-fixer) failed: Syntax error

php-cs-fixer lints a file with the running PHP (8.x) before fixing it, and gives
up on code PHP 8 rejects (`$str{0}`, `create_function`, ...). Check a file with
`php -l <file>`.

**Fix:** `php.lua` turns php-cs-fixer on only when the project root has
`.php-cs-fixer.php`, `.php-cs-fixer.dist.php`, `.php_cs` or `.php_cs.dist`.

To turn it off in a project that has a config, add `.phpactor.json` to the
project root:

```json
{
    "language_server_php_cs_fixer.enabled": false
}
```

Restart phpactor (`:lsp restart` or reopen Neovim). Settings sent from `php.lua`
override `.phpactor.json`, so this only works where `php.lua` doesn't enable the
fixer itself.

## Files

- `lua/genja/lang/php.lua`: `phpactor_cmd()` (wrapper, TCP, ProcessWrapper download).
- `scripts/phpactor-nocheck.php`: the wrapper and its patches.
- `scripts/phpactor-check.lua`: the check above.

## If it breaks after a phpactor update

- "phpactor-nocheck: ... has changed, not patched" on stderr (LSP log): the
  code a patch replaces moved. Update the search string in the wrapper.
- "CreateProcess failed" again: check amphp/process's version in the new
  `.phar` (`vendor/composer/installed.php`) and update the URL in `php.lua`.
