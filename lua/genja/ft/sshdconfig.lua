-- Neovim already knows sshd_config and /etc/ssh/sshd_config.d/*.conf.
---@type vim.filetype.add.filetypes
return {
	pattern = {
		['.*/sshd_config%.d/.*'] = 'sshdconfig', -- any name, outside /etc/ssh too
	},
}
