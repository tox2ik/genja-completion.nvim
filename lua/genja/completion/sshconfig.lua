-- Keywords and values in ssh client config (sshconfig) and sshd_config
-- (sshdconfig).
-- At the start of a line: the option names of that file type (OpenSSH 9.x).
-- After an option: its fixed values (yes/no, LogLevel, StrictHostKeyChecking,
-- ...), Match criteria, and for Ciphers, MACs, KexAlgorithms and the key
-- algorithm lists what the local `ssh -Q` reports (asked once per session;
-- nothing when ssh is not on PATH). File paths (IdentityFile ~/...) come from
-- the path source.

local YN = { 'yes', 'no' }
local LOGLEVEL = { 'QUIET', 'FATAL', 'ERROR', 'INFO', 'VERBOSE', 'DEBUG', 'DEBUG1', 'DEBUG2', 'DEBUG3' }
local FACILITY = { 'DAEMON', 'USER', 'AUTH', 'LOCAL0', 'LOCAL1', 'LOCAL2', 'LOCAL3', 'LOCAL4', 'LOCAL5', 'LOCAL6', 'LOCAL7' }
local FAMILY = { 'any', 'inet', 'inet6' }
local TUNNEL = { 'yes', 'point-to-point', 'ethernet', 'no' }
local FINGERPRINT = { 'sha256', 'md5' }

-- option (lower case) -> `ssh -Q` query
local QUERY = {
	ciphers = 'cipher',
	macs = 'mac',
	kexalgorithms = 'kex',
	hostkeyalgorithms = 'key-sig',
	pubkeyacceptedalgorithms = 'key-sig',
	hostbasedacceptedalgorithms = 'key-sig',
	casignaturealgorithms = 'sig',
}

---@class genja.completion.SshSpec
---@field keywords string[]
---@field values table<string, string[]> option (lower case) -> values

---@type table<string, genja.completion.SshSpec>
local SPEC = {
	sshconfig = {
		keywords = {
			'Host', 'Match', 'Include',
			'AddKeysToAgent', 'AddressFamily', 'BatchMode', 'BindAddress', 'BindInterface',
			'CanonicalDomains', 'CanonicalizeFallbackLocal', 'CanonicalizeHostname', 'CanonicalizeMaxDots',
			'CanonicalizePermittedCNAMEs', 'CASignatureAlgorithms', 'CertificateFile', 'ChannelTimeout',
			'CheckHostIP', 'Ciphers', 'ClearAllForwardings', 'Compression', 'ConnectionAttempts',
			'ConnectTimeout', 'ControlMaster', 'ControlPath', 'ControlPersist', 'DynamicForward',
			'EnableEscapeCommandline', 'EnableSSHKeysign', 'EscapeChar', 'ExitOnForwardFailure',
			'FingerprintHash', 'ForkAfterAuthentication', 'ForwardAgent', 'ForwardX11', 'ForwardX11Timeout',
			'ForwardX11Trusted', 'GatewayPorts', 'GlobalKnownHostsFile', 'GSSAPIAuthentication',
			'GSSAPIDelegateCredentials', 'HashKnownHosts', 'HostbasedAcceptedAlgorithms',
			'HostbasedAuthentication', 'HostKeyAlgorithms', 'HostKeyAlias', 'HostName', 'IdentitiesOnly',
			'IdentityAgent', 'IdentityFile', 'IgnoreUnknown', 'IPQoS', 'KbdInteractiveAuthentication',
			'KbdInteractiveDevices', 'KexAlgorithms', 'KnownHostsCommand', 'LocalCommand', 'LocalForward',
			'LogLevel', 'LogVerbose', 'MACs', 'NoHostAuthenticationForLocalhost', 'NumberOfPasswordPrompts',
			'ObscureKeystrokeTiming', 'PasswordAuthentication', 'PermitLocalCommand', 'PermitRemoteOpen',
			'PKCS11Provider', 'Port', 'PreferredAuthentications', 'ProxyCommand', 'ProxyJump',
			'ProxyUseFdpass', 'PubkeyAcceptedAlgorithms', 'PubkeyAuthentication', 'RekeyLimit',
			'RemoteCommand', 'RemoteForward', 'RequestTTY', 'RequiredRSASize', 'RevokedHostKeys',
			'SecurityKeyProvider', 'SendEnv', 'ServerAliveCountMax', 'ServerAliveInterval', 'SessionType',
			'SetEnv', 'StdinNull', 'StreamLocalBindMask', 'StreamLocalBindUnlink', 'StrictHostKeyChecking',
			'SyslogFacility', 'Tag', 'TCPKeepAlive', 'Tunnel', 'TunnelDevice', 'UpdateHostKeys', 'User',
			'UserKnownHostsFile', 'VerifyHostKeyDNS', 'VisualHostKey', 'XAuthLocation',
		},
		values = {
			match = { 'all', 'canonical', 'final', 'exec', 'localnetwork', 'host', 'originalhost', 'tagged', 'command', 'user', 'localuser', 'version', 'sessiontype' },
			addkeystoagent = { 'yes', 'no', 'ask', 'confirm' },
			addressfamily = FAMILY,
			batchmode = YN,
			canonicalizefallbacklocal = YN,
			canonicalizehostname = { 'yes', 'no', 'always', 'none' },
			checkhostip = YN,
			clearallforwardings = YN,
			compression = YN,
			controlmaster = { 'yes', 'no', 'ask', 'auto', 'autoask' },
			controlpersist = { 'yes', 'no' },
			enableescapecommandline = YN,
			enablesshkeysign = YN,
			exitonforwardfailure = YN,
			fingerprinthash = FINGERPRINT,
			forkafterauthentication = YN,
			forwardagent = YN,
			forwardx11 = YN,
			forwardx11trusted = YN,
			gatewayports = YN,
			gssapiauthentication = YN,
			gssapidelegatecredentials = YN,
			hashknownhosts = YN,
			hostbasedauthentication = YN,
			identitiesonly = YN,
			identityagent = { 'none', 'SSH_AUTH_SOCK' },
			kbdinteractiveauthentication = YN,
			loglevel = LOGLEVEL,
			nohostauthenticationforlocalhost = YN,
			obscurekeystroketiming = YN,
			passwordauthentication = YN,
			permitlocalcommand = YN,
			preferredauthentications = { 'publickey', 'keyboard-interactive', 'password', 'hostbased', 'gssapi-with-mic' },
			proxyusefdpass = YN,
			pubkeyauthentication = { 'yes', 'no', 'unbound', 'host-bound' },
			requesttty = { 'no', 'yes', 'force', 'auto' },
			sessiontype = { 'none', 'subsystem', 'default' },
			stdinnull = YN,
			streamlocalbindunlink = YN,
			stricthostkeychecking = { 'yes', 'accept-new', 'no', 'ask' },
			syslogfacility = FACILITY,
			tcpkeepalive = YN,
			tunnel = TUNNEL,
			updatehostkeys = { 'yes', 'no', 'ask' },
			verifyhostkeydns = { 'yes', 'no', 'ask' },
			visualhostkey = YN,
		},
	},
	sshdconfig = {
		keywords = {
			'Match', 'Include',
			'AcceptEnv', 'AddressFamily', 'AllowAgentForwarding', 'AllowGroups', 'AllowStreamLocalForwarding',
			'AllowTcpForwarding', 'AllowUsers', 'AuthenticationMethods', 'AuthorizedKeysCommand',
			'AuthorizedKeysCommandUser', 'AuthorizedKeysFile', 'AuthorizedPrincipalsCommand',
			'AuthorizedPrincipalsCommandUser', 'AuthorizedPrincipalsFile', 'Banner', 'CASignatureAlgorithms',
			'ChannelTimeout', 'ChrootDirectory', 'Ciphers', 'ClientAliveCountMax', 'ClientAliveInterval',
			'Compression', 'DenyGroups', 'DenyUsers', 'DisableForwarding', 'ExposeAuthInfo', 'FingerprintHash',
			'ForceCommand', 'GatewayPorts', 'GSSAPIAuthentication', 'GSSAPICleanupCredentials',
			'GSSAPIStrictAcceptorCheck', 'HostbasedAcceptedAlgorithms', 'HostbasedAuthentication',
			'HostbasedUsesNameFromPacketOnly', 'HostCertificate', 'HostKey', 'HostKeyAgent', 'HostKeyAlgorithms',
			'IgnoreRhosts', 'IgnoreUserKnownHosts', 'IPQoS', 'KbdInteractiveAuthentication',
			'KerberosAuthentication', 'KerberosGetAFSToken', 'KerberosOrLocalPasswd', 'KerberosTicketCleanup',
			'KexAlgorithms', 'ListenAddress', 'LoginGraceTime', 'LogLevel', 'LogVerbose', 'MACs', 'MaxAuthTries',
			'MaxSessions', 'MaxStartups', 'ModuliFile', 'PasswordAuthentication', 'PermitEmptyPasswords',
			'PermitListen', 'PermitOpen', 'PermitRootLogin', 'PermitTTY', 'PermitTunnel', 'PermitUserEnvironment',
			'PermitUserRC', 'PerSourceMaxStartups', 'PerSourceNetBlockSize', 'PerSourcePenalties',
			'PerSourcePenaltyExemptList', 'PidFile', 'Port', 'PrintLastLog', 'PrintMotd',
			'PubkeyAcceptedAlgorithms', 'PubkeyAuthOptions', 'PubkeyAuthentication', 'RDomain', 'RekeyLimit',
			'RequiredRSASize', 'RevokedKeys', 'SecurityKeyProvider', 'SetEnv', 'StreamLocalBindMask',
			'StreamLocalBindUnlink', 'StrictModes', 'Subsystem', 'SyslogFacility', 'TCPKeepAlive',
			'TrustedUserCAKeys', 'UnusedConnectionTimeout', 'UseDNS', 'UsePAM', 'VersionAddendum',
			'X11DisplayOffset', 'X11Forwarding', 'X11UseLocalhost', 'XAuthLocation',
		},
		values = {
			match = { 'All', 'User', 'Group', 'Host', 'LocalAddress', 'LocalPort', 'RDomain', 'Address' },
			addressfamily = FAMILY,
			allowagentforwarding = YN,
			allowstreamlocalforwarding = { 'yes', 'no', 'all', 'local', 'remote' },
			allowtcpforwarding = { 'yes', 'no', 'all', 'local', 'remote' },
			authenticationmethods = { 'any', 'publickey', 'password', 'keyboard-interactive', 'hostbased', 'gssapi-with-mic' },
			compression = { 'yes', 'delayed', 'no' },
			disableforwarding = YN,
			exposeauthinfo = YN,
			fingerprinthash = FINGERPRINT,
			gatewayports = { 'no', 'yes', 'clientspecified' },
			gssapiauthentication = YN,
			gssapicleanupcredentials = YN,
			gssapistrictacceptorcheck = YN,
			hostbasedauthentication = YN,
			hostbasedusesnamefrompacketonly = YN,
			ignorerhosts = { 'yes', 'shosts-only', 'no' },
			ignoreuserknownhosts = YN,
			kbdinteractiveauthentication = YN,
			kerberosauthentication = YN,
			kerberosgetafstoken = YN,
			kerberosorlocalpasswd = YN,
			kerberosticketcleanup = YN,
			loglevel = LOGLEVEL,
			passwordauthentication = YN,
			permitemptypasswords = YN,
			permitrootlogin = { 'prohibit-password', 'no', 'yes', 'forced-commands-only' },
			permittty = YN,
			permittunnel = TUNNEL,
			permituserenvironment = YN,
			permituserrc = YN,
			printlastlog = YN,
			printmotd = YN,
			pubkeyauthentication = YN,
			pubkeyauthoptions = { 'none', 'touch-required', 'verify-required' },
			streamlocalbindunlink = YN,
			strictmodes = YN,
			subsystem = { 'sftp' },
			syslogfacility = FACILITY,
			tcpkeepalive = YN,
			usedns = YN,
			usepam = YN,
			x11forwarding = YN,
			x11uselocalhost = YN,
		},
	},
}

---@type table<string, string[]>
local queried = {}

---`ssh -Q <query>`, once per session. Runs at most a few ms; empty without ssh.
---@param query string
---@return string[]
local function ssh_query(query)
	if not queried[query] then
		queried[query] = {}
		if vim.fn.executable('ssh') == 1 then
			local res = vim.system({ 'ssh', '-Q', query }, { text = true }):wait(2000)
			if res.code == 0 then
				queried[query] = vim.split(vim.trim(res.stdout or ''), '%s+')
			end
		end
	end
	return queried[query]
end

local source = require('genja.completion.source')

---@param c genja.completion.SourceCtx
---@return lsp.CompletionItem[]
local function items(c)
	local spec = SPEC[vim.bo[c.bufnr].filetype]
	if not spec or c.before:match('^%s*#') then
		return {}
	end
	if c.before:match('^%s*%w*$') then
		return source.labels(spec.keywords, source.kind.Property)
	end
	-- Option, then whitespace and/or '=', then its arguments.
	local option = (c.before:match('^%s*(%w+)[%s=]') or ''):lower()
	local values = spec.values[option]
	if not values and QUERY[option] then
		values = ssh_query(QUERY[option])
	end
	return source.labels(values or {}, source.kind.EnumMember)
end

local FILETYPES = { 'sshconfig', 'sshdconfig' }

---@type genja.completion.Feature
return function(config)
	source.register(config, 'sshconfig', {
		filetypes = FILETYPES,
		with = { 'path', 'buffer' },
		fallbacks = { 'buffer' },
		triggers = { ' ', ',', '=' },
		-- values like aes128-ctr, hmac-sha2-256@openssh.com, accept-new
		replace = '[%w@._-]*',
		items = items,
	})
	-- blink blocks space as a trigger character; the values come after one here
	config.completion.trigger = {
		show_on_blocked_trigger_characters = function()
			if vim.tbl_contains(FILETYPES, vim.bo.filetype) then
				return { '\n', '\t' }
			end
			return { ' ', '\n', '\t' }
		end,
	}
end
