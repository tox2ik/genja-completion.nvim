-- PHP
-- intelephense: completion, hover, diagnostics, go to definition, references.
--               The fast one. Its paid licence is only needed for the features
--               that phpactor covers below.
-- phpactor:     rename, code actions (import class, generate method, ...),
--               go to implementation, go to type definition.
--               Needs PHP 8.2+ on PATH. Linux and macOS only (WSL on Windows).

local servers = {
	intelephense = {},
	-- phpactor = {}, -- only this if you want to use it. skip init_options an on_init below
}

if vim.fn.has('win32') == 0 then
	-- phpactor's README says Linux or macOS only, with WSL for Windows users.
	servers.phpactor = {
		init_options = {
			-- intelephense already reports diagnostics. Delete these three lines
			-- to also get phpactor's (unused imports, missing return types, ...).
			['language_server.diagnostics_on_update'] = false,
			['language_server.diagnostics_on_save'] = false,
			['language_server.diagnostics_on_open'] = false,
		},
		on_init = function(client)
			-- Leave these to intelephense so nothing shows up twice.
			for _, capability in ipairs({
				'completionProvider',
				'hoverProvider',
				'signatureHelpProvider',
				'definitionProvider',
				'referencesProvider',
				'documentSymbolProvider',
				'workspaceSymbolProvider',
				'documentHighlightProvider',
			}) do
				client.server_capabilities[capability] = nil
			end
		end,
	}
end

return {
	servers = servers,
}
