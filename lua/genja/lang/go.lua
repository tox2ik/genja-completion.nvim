-- Go
-- mason builds gopls with `go install`, so Go must be on PATH.
--
-- Root: go.work wins over go.mod, so every module of a multi-module workspace
-- shares one gopls instance rooted at the workspace. Then go.mod, then .git.
-- A root at the home folder is dropped (same guard as lang/lua.lua).
-- Files in the module cache or GOROOT (opened via go-to-definition) reuse the
-- running gopls instead of starting one rooted inside the cache.

local norm = function(p) return vim.fs.normalize(p):lower() end

---Directories gopls should not get its own root in.
---@return string[]
local function go_lib_dirs()
	local dirs = {}
	local gopath = vim.env.GOPATH and vim.split(vim.env.GOPATH, vim.fn.has('win32') == 1 and ';' or ':')[1]
		or vim.fs.joinpath(vim.uv.os_homedir(), 'go')
	table.insert(dirs, vim.env.GOMODCACHE or vim.fs.joinpath(gopath, 'pkg', 'mod'))
	if vim.env.GOROOT then
		table.insert(dirs, vim.env.GOROOT)
	end
	return vim.tbl_map(norm, dirs)
end

---@type genja.Lang
return {
	servers = {
		gopls = {
			root_dir = function(bufnr, on_dir)
				local fname = norm(vim.api.nvim_buf_get_name(bufnr))
				for _, dir in ipairs(go_lib_dirs()) do
					if vim.startswith(fname, dir .. '/') then
						local client = vim.lsp.get_clients({ name = 'gopls' })[1]
						if client and client.root_dir then
							on_dir(client.root_dir)
						end
						return -- no running gopls: don't start one inside the cache
					end
				end

				-- separate lookups: a go.work above a nearer go.mod still wins
				local root = vim.fs.root(bufnr, 'go.work')
					or vim.fs.root(bufnr, 'go.mod')
					or vim.fs.root(bufnr, '.git')
				if root and norm(root) == norm(vim.uv.os_homedir()) then
					root = nil
				end
				on_dir(root) -- nil: single-file mode
			end,
			settings = {
				gopls = {
					gofumpt = false, -- true: stricter formatting (gofumpt rules)
					staticcheck = true,
					completeUnimported = true,
					usePlaceholders = true,
					directoryFilters = { '-**/node_modules' },
					analyses = {
						unusedparams = true,
						unusedwrite = true,
						unusedvariable = true,
						nilness = true,
						useany = true,
						shadow = false, -- noisy with err := ...
					},
					codelenses = {
						generate = true,
						test = true,
						tidy = true,
						upgrade_dependency = true,
						vendor = true,
					},
					-- shown only while inlay hints are on (<leader>tth, map-lsp.lua)
					hints = {
						assignVariableTypes = true,
						compositeLiteralFields = true,
						compositeLiteralTypes = true,
						constantValues = true,
						functionTypeParameters = true,
						parameterNames = true,
						rangeVariableTypes = true,
					},
				},
			},
		},
	},
}
