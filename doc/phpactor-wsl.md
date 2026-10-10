# phpactor in WSL

`lua/genja/lang/php.lua` runs phpactor inside a WSL distro when Neovim runs on
Windows. Linux PHP has ext-posix, ProcessWrapper is not needed, and its event
loop works on a stdin pipe, so none of `phpactor-windows.md`'s workarounds apply.
The native Windows setup is kept as `lua/genja/lang/php.lua.phpactor-windows`.

## Settings

In `lua/genja/lsp/local.lua` (or `config.lua`, or `setup()` opts):

```lua
return {
	enabled = { php = true },
	phpactor_wsl = {
		distro = 'AlmaLinux-9', -- wsl.exe -d; nil: the default distro (`wsl -l -v`)
		install = true,         -- install PHP and phpactor when missing
	},
}
```

## Install

On the first PHP buffer, if `phpactor` or `php` is missing in the distro,
`scripts/phpactor-wsl-install.sh` runs as root (`wsl.exe -u root`, no sudo
password). It detects the family from `/etc/os-release`:

- Debian/Ubuntu: `apt-get install php-cli php-xml php-mbstring php-curl php-zip curl unzip git`
- AlmaLinux/Rocky/RHEL/Fedora: enables the `php:8.3` (or `8.2`) module stream on
  EL8/EL9, then `dnf install php-cli php-xml php-mbstring php-process curl unzip git`

then downloads the latest `phpactor.phar` to `/usr/local/lib/phpactor`, linked as
`/usr/local/bin/phpactor`. phpactor needs PHP 8.2+; Ubuntu 22.04 has 8.1 and
stops with a hint (ondrej PPA).

`:PhpactorWslInstall` runs it again: that is also how phpactor is updated.
The output goes to `stdpath('log')/phpactor-wsl-install.log`.

phpstan, php-cs-fixer, phpcs and pint come from the project's `vendor/bin`, or
from the distro's PATH (`composer global require ...` inside WSL). Mason's
Windows copies are not used.

## How it runs

`wsl.exe [-d distro] --cd /mnt/c/<root> -e /usr/local/bin/phpactor language-server`
over stdio. Every message is translated:

| Neovim (Windows)                            | phpactor (WSL)        |
| ------------------------------------------- | --------------------- |
| `C:\x`, `file:///C:/x`                      | `/mnt/c/x`, `file:///mnt/c/x` |
| `\\wsl.localhost\<distro>\home\x`           | `/home/x`             |
| `file:////wsl.localhost/<distro>/home/x`    | `file:///home/x`      |

Keys holding text (`text`, `newText`, `insertText`, `label`, `value`,
`message`) are left alone. `processId` is sent as null: a Windows PID means
nothing inside WSL.

## Notes

- Projects under `C:\` are read through WSL's file bridge (`/mnt/c`), which is
  slow for indexing big projects. Projects on the Linux side
  (`\\wsl.localhost\<distro>\home\...`) index at native speed.
- phpactor's cache and index live in the distro (`~/.cache/phpactor`).
  `phpactor index:build --reset` runs inside WSL.
- Mason still installs its Windows phpactor: mason-lspconfig only enables
  servers it has installed. It is not run.
