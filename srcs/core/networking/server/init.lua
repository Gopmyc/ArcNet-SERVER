function CORE:Initialize()
	local ENET			= assert(self:GetDependence("enet"),			"[CORE] 'ENET' library is required to initialize the networking core")
	local IP			= assert(self:GetConfig().NETWORK.IP,			"[CORE] 'IP' is required to initialize the networking core")
	local PORT			= assert(self:GetConfig().NETWORK.PORT,			"[CORE] 'PORT' is required to initialize the networking core")
	local MAX_CLIENTS	= assert(self:GetConfig().NETWORK.MAX_CLIENTS,	"[CORE] 'MAX_CLIENTS' is required to initialize the networking core")
	local MAX_CHANNELS	= assert(self:GetConfig().NETWORK.MAX_CHANNELS,	"[CORE] 'MAX_CHANNELS' is required to initialize the networking core")
	local IN_BANDWIDTH	= assert(self:GetConfig().NETWORK.IN_BANDWIDTH,	"[CORE] 'IN_BANDWIDTH' is required to initialize the networking core")
	local OUT_BANDWIDTH	= assert(self:GetConfig().NETWORK.OUT_BANDWIDTH,	"[CORE] 'OUT_BANDWIDTH' is required to initialize the networking core")
	local MESS_TIMEOUT	= assert(self:GetConfig().NETWORK.MESS_TIMEOUT,	"[CORE] 'MESS_TIMEOUT' is required to initialize the networking core")

	local tNetwork	= setmetatable({
		HOST			= ENET.host_create(IP .. ":" .. PORT, MAX_CLIENTS, MAX_CHANNELS, IN_BANDWIDTH, OUT_BANDWIDTH),
		MESS_TIMEOUT	= MESS_TIMEOUT,
		CLIENTS			= setmetatable({}, {__mode = "kv"}),
		NETWORK_ID		= setmetatable({}, {__mode = "kv"}),
		HOOKS			= self:GetLibrary("HOOKS"):Initialize(),
		EVENTS			= self:GetLibrary("EVENTS"):Initialize({
			connect		= self:GetLibrary("SERVER/EVENTS/CONNECT"),
			disconnect	= self:GetLibrary("SERVER/EVENTS/DISCONNECT"),
			receive		= self:GetLibrary("SERVER/EVENTS/RECEIVE"),
			send		= self:GetLibrary("SERVER/EVENTS/SEND"),
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

function CORE:SendToClient(iID, sMessageID, tData, iChannel, sFlag)
	assert(isnumber(iID),			"[CORE] Invalid argument: iID must be a number")
	assert(isstring(sMessageID),	"[CORE] Invalid argument: sMessageID must be a string")
	assert(istable(tData),			"[CORE] Invalid argument: tData must be a table")

	local udPeer	= self:IsValidClient(sID)
	if not udPeer then
		return MsgC(Color(231,76,60), "[CORE] Attempted to send message to unregistered Client [ID : "..sID.."]  : "..tostring(udPeer))
	end

	self.EVENTS:Call(self, self.EVENTS:BuildEvent("send", udPeer, {
		id		=	sMessageID,
		packet	=	tData,
		flag	=	isstring(sFlag) and sFlag or "reliable"
	}, isnumber(iChannel) and iChannel or 0))
end

function CORE:SendToClients(tData, iChannel, sFlag)
	for sID, tClient in pairs(self.CLIENTS) do
		if not (istable(tClient) and next(tClient)) then goto continue end

		self:SendToClient(sID, tData, iChannel, sFlag)

		::continue::
	end
end

function CORE:AddNetworkID(sID)
	assert(isstring(sID), "[CORE] Invalid argument: sID must be a string")

	self.NETWORK_ID[sID]	= true
end

function CORE:SubNetworkID(sID)
	assert(isstring(sID), "[CORE] Invalid argument: sID must be a string")

	self.NETWORK_ID[sID]	= nil
end

function CORE:IsValidClient(sID)
	return
		(
			isstring(sID) and
			istable(self.CLIENTS[sID]) and
			next(self.CLIENTS[sID])
		) and
	self.CLIENTS[sID] or false
end

function CORE:IsValidMessage(sID)
	return isstring(sID) and self.NETWORK_ID[sID]
end

function CORE:AddHook(sID, fCallBack)
	self.HOOKS:AddHook(sID, fCallBack)
end

function CORE:Destroy()

	-- TODO: Kick all clients before destroying the server
	if istable(self.CLIENTS) then
		for sID, _ in pairs(self.CLIENTS) do
			self.CLIENTS[sID] = nil
		end
	end

	if istable(self.NETWORK_ID) then
		for sID, _ in pairs(self.NETWORK_ID) do
			self.NETWORK_ID[sID] = nil
		end
	end

	if istable(self.HOOKS) and isfunction(self.HOOKS.Destroy) then
		pcall(function() self.HOOKS:Destroy() end)
	end
	self.HOOKS = nil

	if istable(self.EVENTS) and isfunction(self.EVENTS.Destroy) then
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