function CORE:Initialize()
	local ENET				= assert(self:GetDependence("enet"),				"[CORE] 'ENET' library is required to initialize the networking core")
	local IP				= assert(self:GetConfig().NETWORK.IP,				"[CORE] 'IP' is required to initialize the networking core")
	local PORT				= assert(self:GetConfig().NETWORK.PORT,				"[CORE] 'PORT' is required to initialize the networking core")
	local MAX_CLIENTS		= assert(self:GetConfig().NETWORK.MAX_CLIENTS,		"[CORE] 'MAX_CLIENTS' is required to initialize the networking core")
	local MAX_CHANNELS		= assert(self:GetConfig().NETWORK.MAX_CHANNELS,		"[CORE] 'MAX_CHANNELS' is required to initialize the networking core")
	local IN_BANDWIDTH		= assert(self:GetConfig().NETWORK.IN_BANDWIDTH,		"[CORE] 'IN_BANDWIDTH' is required to initialize the networking core")
	local OUT_BANDWIDTH		= assert(self:GetConfig().NETWORK.OUT_BANDWIDTH,	"[CORE] 'OUT_BANDWIDTH' is required to initialize the networking core")
	local MESS_TIMEOUT		= assert(self:GetConfig().NETWORK.MESS_TIMEOUT,		"[CORE] 'MESS_TIMEOUT' is required to initialize the networking core")
	local ENCRYPTION_KEY	= assert(self:GetConfig().NETWORK.ENCRYPTION_KEY,	"[CORE] 'ENCRYPTION_KEY' is required to initialize the networking core")
	local DEFAULT_ENCRYPT	= assert(self:GetConfig().NETWORK.DEFAULT_ENCRYPT,		"[CORE] 'DEFAULT_ENCRYPT' is required to initialize the networking core")
	local DEFAULT_COMPRESS	= assert(self:GetConfig().NETWORK.DEFAULT_COMPRESS,	"[CORE] 'DEFAULT_COMPRESS' is required to initialize the networking core")

	local tNetwork	= setmetatable({
		HOST				= ENET.host_create(IP .. ":" .. PORT, MAX_CLIENTS, MAX_CHANNELS, IN_BANDWIDTH, OUT_BANDWIDTH),
		MESS_TIMEOUT		= MESS_TIMEOUT,
		DEFAULT_ENCRYPT		= DEFAULT_ENCRYPT,
		DEFAULT_COMPRESS	= DEFAULT_COMPRESS,
		CLIENTS				= setmetatable({}, {__mode = "kv"}),
		NETWORK_ID			= setmetatable({}, {__mode = "kv"}),
		HOOKS				= self:GetLibrary("HOOKS"):Initialize(),
		CODEC				= self:GetLibrary("CODEC"):Initialize(
			self:GetDependence("JSON"),
			self:GetDependence("CHACHA20"),
			self:GetDependence("POLY1305"),
			self:GetDependence("LZW"),
			self:GetDependence("BASE64"),
			ENCRYPTION_KEY
		),
		EVENTS				= self:GetLibrary("EVENTS"):Initialize({
			connect		= self:GetLibrary("SERVER/EVENTS/CONNECT"),
			disconnect	= self:GetLibrary("SERVER/EVENTS/DISCONNECT"),
			receive		= self:GetLibrary("SERVER/EVENTS/RECEIVE"),
			send		= self:GetLibrary("SERVER/EVENTS/SEND"),
			unhandled	= self:GetLibrary("SERVER/EVENTS/UNHANDLED"),
		}),
	}, {__index = CORE})

	MsgC(Color(52, 152, 219), "[INFO] Networking server initialized on " .. IP .. ":" .. PORT )

	return tNetwork
end

function CORE:GetHost()
	return self.HOST
end

function CORE:Update(iDt)
	local tEvent	=	self.HOST:service(self.MESS_TIMEOUT)
	while tEvent do
		xpcall(
			function()
				return self.EVENTS:Call(self, tEvent)
			end,
			function(sErr)
				return MsgC(Color(231, 76, 60), "[ERROR] Unhandled ENet event error: " .. tostring(sErr))
			end
		)
		
		tEvent	= self.HOST:service(self.MESS_TIMEOUT)
	end
end

function CORE:SendToClient(sID, tPacket, iChannel, sFlag)
	assert(IsString(sID),			"[SERVER] Invalid argument: sID must be a number")
	assert(IsTable(tPacket),		"[SERVER] Invalid argument: tPacket must be a table")

	sFlag	= ((sFlag == "unsequenced") or (sFlag == "unreliable") or (sFlag == "reliable")) and sFlag or "reliable"

	local tPeer	= self:IsValidClient(sID)
	if not tPeer then
		return MsgC(Color(231,76,60), "[ERROR] Attempted to send message to unregistered Client [ID : "..sID.."]  : "..tostring(tPeer[1]))
	end

	self.EVENTS:Call(self, {
		type	= "send",
		peer	= tPeer[1],
		data	= tPacket,
		channel	= iChannel or 0,
		flag	= sFlag,
	})
end

function CORE:SendToClients(tData, iChannel, sFlag)
	for sID, tClient in pairs(self.CLIENTS) do
		if not (IsTable(tClient) and next(tClient)) then goto continue end

		self:SendToClient(sID, tData, iChannel, sFlag)

		::continue::
	end
end

function CORE:BuildPacket(sMessageID, Content, bCrypt, bCompress)
	assert(IsString(sMessageID),	"[SERVER] Invalid argument: sMessageID must be a string")
	assert(Content ~= nil,			"[SERVER] Invalid argument: Content must not be nil")

	bCrypt		= (bCrypt == true)		and true or self.DEFAULT_ENCRYPT
	bCompress	= (bCompress == true)	and true or self.DEFAULT_COMPRESS

	return {
		ID			= sMessageID,
		CONTENT		= Content,
		ENCRYPTED	= bCrypt,
		COMPRESSED	= bCompress,
	}
end

function CORE:AddNetworkID(sID)
	assert(IsString(sID), "[CORE] Invalid argument: sID must be a string")

	self.NETWORK_ID[sID]	= true
end

function CORE:SubNetworkID(sID)
	assert(IsString(sID), "[CORE] Invalid argument: sID must be a string")

	self.NETWORK_ID[sID]	= nil
end

function CORE:IsValidClient(sID)
	return
		(
			IsString(sID) and
			IsTable(self.CLIENTS[sID]) and
			next(self.CLIENTS[sID])
		) and
	self.CLIENTS[sID] or false
end

function CORE:IsValidMessage(sID)
	return IsString(sID) and self.NETWORK_ID[sID]
end

function CORE:AddHook(sID, fCallBack)
	self.HOOKS:AddHook(sID, fCallBack)
end

function CORE:Destroy()

	-- TODO: Kick all clients before destroying the server
	if IsTable(self.CLIENTS) then
		for sID, _ in pairs(self.CLIENTS) do
			self.CLIENTS[sID] = nil
		end
	end

	if IsTable(self.NETWORK_ID) then
		for sID, _ in pairs(self.NETWORK_ID) do
			self.NETWORK_ID[sID] = nil
		end
	end

	if IsTable(self.HOOKS) and IsFunction(self.HOOKS.Destroy) then
		pcall(function() self.HOOKS:Destroy() end)
	end
	self.HOOKS = nil

	if IsTable(self.EVENTS) and IsFunction(self.EVENTS.Destroy) then
		pcall(function() self.EVENTS:Destroy() end)
	end
	self.EVENTS = nil

	if self.HOST then
		pcall(function()
			self.HOST:flush()
			self.HOST = nil
		end)
	end

	setmetatable(self, nil)
end