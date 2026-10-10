<?php
// Copy to the project root. With this file present, genja's php.lua turns on
// phpactor's php-cs-fixer diagnostics and formatting (not in WordPress or Laravel).
// Needs php-cs-fixer in vendor/bin (composer require --dev friendsofphp/php-cs-fixer)
// or on PATH (Mason: :MasonInstall php-cs-fixer).

$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__)
    ->exclude(['vendor', 'var', 'cache', 'node_modules']);

return (new PhpCsFixer\Config())
    ->setRiskyAllowed(false)
    ->setRules([
        '@PSR12' => true,
    ])
    ->setFinder($finder);
