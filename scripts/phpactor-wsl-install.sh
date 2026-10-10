#!/bin/sh
# Installs or updates PHP 8.2+ and phpactor in a WSL distro, for genja's
# lua/genja/lang/php.lua. Run as root; :PhpactorWslInstall does it with
#   wsl.exe [-d <distro>] -u root -e sh -s < phpactor-wsl-install.sh
#
# Debian/Ubuntu: apt. AlmaLinux/Rocky/RHEL/CentOS Stream/Fedora: dnf (or yum).
# On EL8/EL9 the newest php module stream (8.3, else 8.2) is enabled first.
# phpactor.phar goes to /usr/local/lib/phpactor, linked as /usr/local/bin/phpactor,
# its phpstorm-stubs to /usr/local/lib/phpactor/phpstorm-stubs.
set -eu

PHAR_URL=https://github.com/phpactor/phpactor/releases/latest/download/phpactor.phar
DIR=/usr/local/lib/phpactor

if [ "$(id -u)" != 0 ]; then
	echo "run as root: wsl.exe -u root ..." >&2
	exit 1
fi

. /etc/os-release
family=" ${ID:-} ${ID_LIKE:-} "
echo "== $PRETTY_NAME"

case "$family" in
*" debian "* | *" ubuntu "*)
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -q
	apt-get install -y -q php-cli php-xml php-mbstring php-curl php-zip \
		curl ca-certificates unzip git
	;;
*" rhel "* | *" centos "* | *" fedora "*)
	pm=dnf
	command -v dnf >/dev/null 2>&1 || pm=yum
	# EL8/EL9 ship old PHP by default and newer ones as module streams.
	# EL10 and Fedora have no php module; this is skipped there.
	if [ "$ID" != fedora ] && streams=$($pm -q module list php 2>/dev/null); then
		for s in 8.3 8.2; do
			if echo "$streams" | grep -Eq "^php +$s "; then
				echo "== enabling php:$s"
				$pm -y -q module reset php
				$pm -y -q module enable "php:$s"
				break
			fi
		done
	fi
	# php-process: posix and pcntl.
	$pm install -y -q php-cli php-xml php-mbstring php-process \
		curl ca-certificates unzip git
	;;
*)
	echo "unsupported distro '$ID' (ID_LIKE '${ID_LIKE:-}'): install PHP 8.2+ and phpactor by hand" >&2
	exit 2
	;;
esac

if ! php -r 'exit(PHP_VERSION_ID >= 80200 ? 0 : 1);'; then
	echo "PHP $(php -r 'echo PHP_VERSION;') is too old, phpactor needs 8.2+." >&2
	case "$family" in
	*" ubuntu "*) echo "Ubuntu: add-apt-repository ppa:ondrej/php, install php8.3-cli etc., then rerun." >&2 ;;
	*" debian "*) echo "Debian: use packages.sury.org/php, or Debian 12+." >&2 ;;
	esac
	exit 3
fi

echo "== phpactor"
mkdir -p "$DIR"
curl -fsSL -o "$DIR/phpactor.phar.part" "$PHAR_URL"
chmod 755 "$DIR/phpactor.phar.part"
mv -f "$DIR/phpactor.phar.part" "$DIR/phpactor.phar"
ln -sf "$DIR/phpactor.phar" /usr/local/bin/phpactor

# PHP's own stubs, copied out of the .phar: phpactor would otherwise index and
# link them as phar:// paths, which Neovim on Windows can't open.
echo "== phpstorm-stubs"
rm -rf "$DIR/phpstorm-stubs.part"
php -r '
$src = "phar://" . $argv[1] . "/vendor/jetbrains/phpstorm-stubs";
$dst = $argv[2];
$files = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($src, FilesystemIterator::SKIP_DOTS));
foreach ($files as $file) {
	$to = $dst . "/" . substr($file->getPathname(), strlen($src) + 1);
	is_dir(dirname($to)) || mkdir(dirname($to), 0755, true);
	copy($file->getPathname(), $to) || exit(1);
}
' "$DIR/phpactor.phar" "$DIR/phpstorm-stubs.part"
rm -rf "$DIR/phpstorm-stubs"
mv "$DIR/phpstorm-stubs.part" "$DIR/phpstorm-stubs"

php --version | head -n 1
phpactor --version
