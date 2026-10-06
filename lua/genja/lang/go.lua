-- Go (mason builds gopls with `go install`, so Go must be installed)
return {
	servers = {
		gopls = {
			settings = {
				gopls = {
					completeUnimported = true,
					usePlaceholders = true,
					analyses = {
						unusedparams = true,
					},
				},
			},
		},
	},
}
