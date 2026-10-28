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
			},
			settings = {
				powershell = {
					-- section and keys as read by the installed PSES (its dll strings)
					rename = {
						acceptDisclaimer = true, -- skip the per-session "limited rename" prompt
						createParameterAlias = false, -- no [Alias('oldName')] on renamed parameters
					},
				},
			},
		},
	}
}
