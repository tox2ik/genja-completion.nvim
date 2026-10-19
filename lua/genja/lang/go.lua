-- Go
-- mason builds gopls with `go install`, so Go must be on PATH.
--
-- Root: go.work wins over go.mod, so every module of a multi-module workspace
-- shares one gopls instance rooted at the workspace. Then go.mod, then .git.
-- A root at the home folder is dropped (same guard as lang/lua.lua).
-- Files in the module cache or GOROOT (opened via go-to-definition) reuse the
-- running gopls instead of starting one rooted inside the cache.
--
-- A .go file with no go.mod/go.work above it puts gopls in single-file mode,
-- where code actions fail with "missing metadata"; that warns once per folder.
--
-- On save: source.organizeImports, then format. Off for one buffer with
-- `:let b:go_format_on_save = v:false`, everywhere with `g:go_format_on_save`.
--
-- Settings checked against gopls v0.23 (`gopls api-json`). Left out because
-- they are defaults now: analyses unusedparams, unusedwrite, unusedvariable,
-- nilness; codelenses generate, tidy, upgrade_dependency, vendor;
-- directoryFilters '-**/node_modules'. Removed from gopls: completeUnimported
-- (always on), the useany analyzer.

local SRC = 'nvim/plug-wip/genja-completion011.nvim/lua/genja/lang/go.lua'
local SAVE_TIMEOUT = 1000 -- ms per request; on timeout the file is saved as is

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

local warned = {} ---@type table<string, true> folders already warned about

---Warn when no go.mod/go.work is above a .go file, with the command that fixes it.
---@param bufnr integer
local function warn_rootless(bufnr)
	local fname = vim.api.nvim_buf_get_name(bufnr)
	if fname == '' or vim.bo[bufnr].filetype ~= 'go' then
		return
	end
	if vim.env.GO111MODULE == 'off' then
		return -- GOPATH mode on purpose
	end
	if vim.fs.root(bufnr, { 'go.work', 'go.mod' }) then
		return
	end
	local dir = vim.fs.dirname(vim.fs.normalize(fname))
	if warned[dir] then
		return
	end
	warned[dir] = true
	vim.notify(
		('%s: no go.mod or go.work above %s; gopls runs in single-file mode and code actions'
			.. ' fail with "missing metadata". Fix: cd %s && go mod init %s')
			:format(SRC, dir, dir, vim.fs.basename(dir)),
		vim.log.levels.WARN
	)
end

---Apply source.organizeImports synchronously, so it can run in BufWritePre.
---@param client vim.lsp.Client
---@param bufnr integer
local function organize_imports(client, bufnr)
	-- whole-file action: the range is ignored, so no window/cursor is needed
	local params = {
		textDocument = { uri = vim.uri_from_bufnr(bufnr) },
		range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 0 } },
		context = { only = { 'source.organizeImports' }, diagnostics = {} },
	}
	local resp = client:request_sync('textDocument/codeAction', params, SAVE_TIMEOUT, bufnr)
	if not resp or resp.err or not resp.result then
		return -- timeout, or no package metadata (rootless file)
	end
	for _, action in ipairs(resp.result) do
		local resolved = action
		-- gopls leaves out the edit when the client can resolve it later
		if not resolved.edit and client:supports_method('codeAction/resolve', bufnr) then
			local r = client:request_sync('codeAction/resolve', action, SAVE_TIMEOUT, bufnr)
			if r and r.result then
				resolved = r.result
			end
		end
		if resolved.edit then
			vim.lsp.util.apply_workspace_edit(resolved.edit, client.offset_encoding)
		end
	end
end

---@param bufnr integer
---@return boolean
local function format_on_save(bufnr)
	if vim.b[bufnr].go_format_on_save == false then
		return false
	end
	return vim.g.go_format_on_save ~= false
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

				warn_rootless(bufnr)

				-- separate lookups: a go.work above a nearer go.mod still wins
				local root = vim.fs.root(bufnr, 'go.work')
					or vim.fs.root(bufnr, 'go.mod')
					or vim.fs.root(bufnr, '.git')
				if root and norm(root) == norm(vim.uv.os_homedir()) then
					root = nil
				end
				on_dir(root) -- nil: single-file mode
			end,
			on_attach = function(client, bufnr)
				if vim.bo[bufnr].filetype ~= 'go' then
					return
				end
				vim.api.nvim_create_autocmd('BufWritePre', {
					-- one group per buffer: a restarted gopls replaces the old hook
					group = vim.api.nvim_create_augroup('genja.go.save.' .. bufnr, { clear = true }),
					buffer = bufnr,
					desc = 'gopls: organize imports, then format',
					callback = function()
						if client:is_stopped() or not format_on_save(bufnr) then
							return
						end
						organize_imports(client, bufnr)
						vim.lsp.buf.format({ bufnr = bufnr, id = client.id, timeout_ms = SAVE_TIMEOUT })
					end,
				})
			end,
			settings = {
				gopls = {
					gofumpt = false, -- true: stricter formatting (gofumpt rules)
					staticcheck = true, -- SA/S/QF checks, many come with quickfixes
					usePlaceholders = true,
					analyses = {
						shadow = false, -- off by default; noisy with err := ...
					},
					codelenses = {
						test = true, -- off by default
					},
					-- shown only while inlay hints are on (<leader>tth, map-lsp.lua)
					hints = {
						assignVariableTypes = true,
						compositeLiteralFields = true,
						compositeLiteralTypes = true,
						constantValues = true,
						functionTypeParameters = true,
						ignoredError = true,
						parameterNames = true,
						rangeVariableTypes = true,
					},
				},
			},
		},
	},
}
