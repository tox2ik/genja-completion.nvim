-- :checkhealth genja.lsp
local installed = require('genja.lsp.installed')
local venv = require('genja.lsp.venv')
local shim = require('genja.lsp.shim')

local M = {}

local function check_servers()
	vim.health.start('servers of the enabled languages')
	local list = installed.list()
	if #list == 0 then
		vim.health.info('no language enabled')
		return
	end
	for _, item in ipairs(list) do
		if item.note and item.ok then
			vim.health.info(item.server .. ': ' .. item.note)
		elseif item.ok then
			vim.health.ok(item.server .. ': ' .. item.cmd)
		elseif item.note then
			vim.health.error(item.server .. ': ' .. item.note)
		else
			vim.health.error(item.server .. ': ' .. item.cmd .. ' is not executable', { installed.fix(item) })
		end
	end
end

local function check_venvs()
	vim.health.start('mason Python venvs (' .. venv.packages_dir() .. ')')
	local list = venv.list()
	if #list == 0 then
		vim.health.info('no mason package with a Python venv')
		return
	end
	for _, v in ipairs(list) do
		if v.ok then
			vim.health.ok(v.name .. ': ' .. v.python)
		elseif not v.home then
			vim.health.error(v.name .. ': no `home =` in ' .. v.cfg, { venv.fix(v) })
		else
			vim.health.error(v.name .. ': its Python is gone: ' .. v.python
				.. ' (the tool exits with code 103)', { venv.fix(v) })
		end
	end
end

local function check_shims()
	vim.health.start('mason launchers (' .. shim.bin_dir() .. ')')
	local list = shim.list()
	if #list == 0 then
		vim.health.info('no launchers')
		return
	end
	local good = 0
	for _, s in ipairs(list) do
		if s.ok then
			good = good + 1
			if s.absolute then
				vim.health.warn(s.name .. ': written by an older mason with a full path; breaks if the mason folder moves',
					{ shim.fix(s) })
			end
		elseif s.target then
			vim.health.error(s.name .. ': its target is gone: ' .. s.target, { shim.fix(s) })
		else
			vim.health.warn(s.name .. ': no target found in it', { shim.fix(s) })
		end
	end
	-- one line for the good ones: there are dozens
	vim.health.ok(('%d of %d launchers start an existing file'):format(good, #list))
end

function M.check()
	check_servers()
	check_venvs()
	check_shims()
end

return M
