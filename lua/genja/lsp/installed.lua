-- Is every server an enabled language wants actually runnable? mason-lspconfig only enables a
-- server once it is installed, so a missing one never starts and nothing says why.
--
--   require('genja.lsp.installed').list()   each wanted server, its command and whether it runs
--
-- Needs the real config (vim.lsp.config filled by setup()). Used by :checkhealth genja.lsp and
-- the config's tests/comps011 case `mason: servers installed`.

local M = {}

---@class genja.lsp.Installed
---@field server string lspconfig name
---@field cmd string|nil first word of its cmd; nil when cmd is a function or unset
---@field ok boolean cmd is executable (true for function cmds: not checkable here)
---@field note string|nil why it can't be checked

---One server, wanted or not.
---@param server string lspconfig name
---@return genja.lsp.Installed
function M.check(server)
	local item = { server = server, ok = false }
	local config = vim.lsp.config[server]
	local cmd = config and config.cmd
	if type(cmd) == 'table' and cmd[1] then
		item.cmd = cmd[1]
		item.ok = vim.fn.executable(cmd[1]) == 1
	elseif type(cmd) == 'function' then
		item.ok = true
		item.note = 'cmd is a function, not checked'
	else
		item.note = 'no cmd: no vim.lsp.config for it (nvim-lspconfig not loaded?)'
	end
	return item
end

---Every server the enabled languages want.
---@return genja.lsp.Installed[]
function M.list()
	local result = {}
	for _, server in ipairs(require('genja.lsp').servers()) do
		table.insert(result, M.check(server))
	end
	return result
end

---What to do about a missing server.
---@param item genja.lsp.Installed
---@return string
function M.fix(item)
	return ':MasonInstall ' .. item.server .. ' (lspconfig name; :Mason shows the package),'
		.. ' or turn the language off in lua/genja/lsp/local.lua'
end

return M
