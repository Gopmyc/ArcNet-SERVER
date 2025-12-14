-- Fetch default config server settings
-- Fetch enet module

print(CORE:GetDependence("enet"))

function CORE:Initialize()
	return setmetatable({
		CLIENTS			= setmetatable({}, {__mode = "kv"}),
		NETWORK_ID		= setmetatable({}, {__mode = "kv"}),
		-- HOOKS			= {},
		-- EVENTS			= {},
		-- MESS_TIMEOUT	= nil,
		-- HOST			= Enet.host_create( IP:PORT, MAX_CLIENTS, CHANNELS, IN_BANDWIDTH, OUT_BANDWIDTH ),
	}, {__index = CORE})
end

function CORE:GetHost()
	return self.HOST
end

function CORE:Update(iDt)
	local tEvent	=	self.HOST:service(self.MESS_TIMEOUT)
	while tEvent do
		self.EVENTS:Call(self, tEvent)
		tEvent		=	self.HOST:service(self.MESS_TIMEOUT)
	end
end

function CORE:Close()
	if not self.HOST then return MsgC(Color(231,76,60), "[CORE] HOST is already nil on 'Close") end

	self.HOST:flush()
	self.HOST	= nil
end

function CORE:SendToClient(iID, sMessageID, tData, iChannel, sFlag)
	assert(isnumber(iID),			"[CORE] Invalid argument: iID must be a number")
	assert(isstring(sMessageID),	"[CORE] Invalid argument: sMessageID must be a string")
	assert(istable(tData),			"[CORE] Invalid argument: tData must be a table")

	local tPeer	= self:IsValidClient(sID)
	if not tPeer then
		return MsgC(Color(231,76,60), "[CORE] Attempted to send message to unregistered Client [ID : "..sID.."]  : "..tostring(tPeer))
	end

	self.EVENTS:Call(self, self.EVENTS:BuildEvent("send", tPeer, {
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
	return (isstring(sID) and istable(self.CLIENTS[sID]) and next(self.CLIENTS[sID])) and self.CLIENTS[sID] or false
end

function CORE:IsValidMessage(sID)
	return isstring(sID) and self.NETWORK_ID[sID]
end

function CORE:AddHook(sID, fCallBack)
	self.HOOKS:AddHook(sID, fCallBack)
end
