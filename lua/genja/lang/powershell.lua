-- PowerShell
-- The only server available. It runs inside pwsh, so it is slow to start.
return {
	servers = {
		powershell_es = {
			-- shell = 'powershell', -- Windows PowerShell 5.1 instead of pwsh 7
		},
	},
}
