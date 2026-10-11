---@type genja.Lang
return {
	servers = {
		-- powershell_es = { shell = 'powershell', }, -- Windows PowerShell 5.1 instead of pwsh 7
		powershell_es = {
			shell = "pwsh",
			args = {
				"-NoLogo",
				"-NoProfile",
				"-NonInteractive",
			}
		},
	}
}
