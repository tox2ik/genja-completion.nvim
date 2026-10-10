# PHP project configs

Copy into a project root to turn on the tools phpactor runs (see
`lua/genja/lang/php.lua`, `project_options()`):

| File                     | Turns on      | Also accepted                              |
|--------------------------|---------------|--------------------------------------------|
| `.php-cs-fixer.dist.php` | php-cs-fixer  | `.php-cs-fixer.php`, `.php_cs`, `.php_cs.dist` |
| `phpstan.neon.dist`      | phpstan       | `phpstan.neon`, `phpstan.dist.neon`        |

php-cs-fixer stays off in WordPress and Laravel projects even with a config.
Restart phpactor after adding a file (`:lsp restart`).
