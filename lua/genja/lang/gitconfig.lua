-- Git config files (.gitconfig, .git/config, .gitmodules)
-- No maintained language server; ftplugin/gitconfig.lua reports git's own
-- parse errors as diagnostics while this language is enabled.
---@type genja.Lang
return {
	note = 'parse errors: ftplugin/gitconfig.lua',
}
