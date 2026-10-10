# Go workspace sample

A two-module workspace to check gopls root detection (`lua/genja/lang/go.lua`):

```
go.work         use ./app and ./greet
app/            module example.com/app, imports greet
greet/          module example.com/greet
```

Open `app/main.go`, then `greet/greet.go`: both should attach to one gopls
whose root is this folder (where `go.work` is), not `app/` or `greet/`.
Go-to-definition on `greet.Hello` in `main.go` jumps into `greet/`, which
only resolves through `go.work` (app has no require or replace for it).

Check with `:checkhealth vim.lsp` or `:lua =vim.lsp.get_clients({ name = 'gopls' })[1].root_dir`.

Enable Go for one machine in `lua/genja/lsp/local.lua` of your Neovim config:

```lua
return { enabled = { go = true } }
```
