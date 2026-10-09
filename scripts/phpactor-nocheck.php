<?php
// Starts phpactor.phar without its ext-posix checks, which Windows PHP can't pass.
// Phpactor only calls posix_* behind function_exists() or on Unix-only paths.
//
// Usage: php phpactor-nocheck.php <path to phpactor.phar> <phpactor arguments...>
//
// The .phar path is kept in PHPACTOR_PHAR, and phpactor is told this script is
// its binary, so the index workers it spawns (php <bin> index:worker ...) come
// back through here instead of hitting the checks.

if (isset($argv[1]) && str_ends_with($argv[1], '.phar')) {
    putenv('PHPACTOR_PHAR=' . $argv[1]);
    array_splice($argv, 1, 1);
}
$phar = getenv('PHPACTOR_PHAR') ?: '';
if (!is_file($phar)) {
    fwrite(STDERR, "phpactor.phar not found: '{$phar}'\n");
    exit(255);
}

$_SERVER['argv'] = $argv;
$_SERVER['argc'] = $argc = count($argv);

error_reporting(E_ALL ^ E_DEPRECATED ^ E_NOTICE);
ini_set('display_errors', 'stderr');

// The same as phpactor's bin/phpactor, minus the extension check.
Phar::loadPhar($phar, 'phpactor.phar');
require 'phar://phpactor.phar/vendor/autoload.php';

/**
 * Load a class from the .phar with one piece of code replaced, before the
 * autoloader loads the original.
 */
function phpactor_patch(string $file, string $search, string $replace): void
{
    $code = file_get_contents('phar://phpactor.phar/' . $file);
    $code = str_replace($search, $replace, $code, $count);
    if ($count !== 1) {
        fwrite(STDERR, "phpactor-nocheck: {$file} has changed, not patched\n");
        return;
    }
    eval('?>' . $code);
}

if (PHP_OS_FAMILY === 'Windows') {
    // Stub paths (built-in functions and classes) get the include pattern /**/*
    // without a drive letter, so no stub file ever matches C:/... and array_map
    // and friends are never indexed. Let that catch-all pattern match everything.
    phpactor_patch(
        'lib/Filesystem/Domain/FileList.php',
        'if (Glob::match($path, $glob)) {',
        "if (\$glob === '/**/*' || Glob::match(\$path, \$glob)) {"
    );

    // amphp/process starts programs (php -l, phpstan, php-cs-fixer) through
    // ProcessWrapper64.exe, which the .phar leaves out. genja's php.lua downloads
    // it next to the .phar; use that copy.
    $wrapper = dirname($phar) . '\\ProcessWrapper64.exe';
    if (is_file($wrapper)) {
        phpactor_patch(
            'vendor/amphp/process/lib/Internal/Windows/Runner.php',
            "BIN_DIR . '\\\\windows\\\\ProcessWrapper64.exe'",
            var_export($wrapper, true)
        );
    }
}

// Self-test for scripts/phpactor-check.lua: lint broken code with `php -l`
// through amphp/process, as phpactor's "php" diagnostic does, and print the result.
if (getenv('PHPACTOR_CHECK_PROCESS')) {
    echo Amp\Promise\wait(Amp\call(function () {
        $process = new Amp\Process\Process([PHP_BINARY, '-l', '-d', 'display_errors=stdout']);
        yield $process->start();
        yield $process->getStdin()->write("<?php\n\$x = ;\n");
        yield $process->getStdin()->end();
        $output = yield Amp\ByteStream\buffer($process->getStdout());
        yield $process->join();
        return $output;
    }));
    exit(0);
}

// Index a copy of the PHP stubs next to the .phar rather than the ones inside it,
// refreshed once per phpactor version. PHPACTOR_STUBS_OUTSIDE_PHAR=1 does the
// same on other systems.
if (PHP_OS_FAMILY === 'Windows' || getenv('PHPACTOR_STUBS_OUTSIDE_PHAR')) {
    $stubs = dirname($phar) . '/phpstorm-stubs';
    $stamp = $stubs . '/.phar-mtime';
    if (@file_get_contents($stamp) !== (string) filemtime($phar)) {
        $source = 'phar://phpactor.phar/vendor/jetbrains/phpstorm-stubs';
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($source, FilesystemIterator::SKIP_DOTS)
        );
        foreach ($files as $file) {
            $target = $stubs . substr($file->getPathname(), strlen($source));
            @mkdir(dirname($target), 0777, true);
            copy($file->getPathname(), $target);
        }
        file_put_contents($stamp, (string) filemtime($phar));
    }

    // Replaces phpactor's own stub path (the one inside the .phar).
    // The language server's initializationOptions can still override this.
    $extra = ['indexer.stub_paths' => [str_replace('\\', '/', $stubs)]];
    foreach ($argv as $i => $arg) {
        if (str_starts_with($arg, '--config-extra=')) {
            $given = json_decode(substr($arg, strlen('--config-extra=')), true) ?: [];
            $argv[$i] = '--config-extra=' . json_encode(array_merge($extra, $given));
            $extra = null;
        }
    }
    if ($extra) {
        $argv[] = '--config-extra=' . json_encode($extra);
    }
    $_SERVER['argv'] = $argv;
    $_SERVER['argc'] = $argc = count($argv);
}

$application = new Phpactor\Application('phar://phpactor.phar/vendor', __FILE__);
$output = new Symfony\Component\Console\Output\ConsoleOutput();
try {
    $application->run(null, $output);
} catch (Exception $e) {
    $application->renderThrowable($e, $output);
    exit(255);
}
