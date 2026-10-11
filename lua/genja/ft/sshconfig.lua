-- Neovim already knows ssh_config, ~/.ssh/config, ~/.ssh/*.conf and
-- /etc/ssh/ssh_config.d/*.conf.
---@type vim.filetype.add.filetypes
return {
	pattern = {
		['.*/%.ssh/config%.d/.*'] = 'sshconfig', -- Include ~/.ssh/config.d/* (any name)
		['.*/%.ssh/config[%.%-_].+'] = 'sshconfig', -- config.local, config-work
		['.*/ssh_config%.d/.*'] = 'sshconfig', -- any name, outside /etc/ssh too
	},
}
