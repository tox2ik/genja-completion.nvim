-- SSH client config (~/.ssh/config, ssh_config, config.d/*)
-- No language server in nvim-lspconfig or Mason; ftplugin/sshconfig.lua
-- reports ssh's own parse errors as diagnostics while this language is enabled.
-- Keyword and value completion is the sshconfig completion feature, which
-- also covers sshd_config.
---@type genja.Lang
return {}
