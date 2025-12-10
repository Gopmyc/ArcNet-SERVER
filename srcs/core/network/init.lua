-- Fetch default config server settings
-- Fetch enet module

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
	if not self.HOST then return MsgC(Color(231,76,60), "[CORE] HOST is already nil on 'Close'\n") end

	self.HOST:flush()
	self.HOST	= nil
end

function CORE:SendToClient(iID, sMessageID, tData, iChannel, sFlag)
	assert(isnumber(iID),			"[CORE] Invalid argument: iID must be a number")
	assert(isstring(sMessageID),	"[CORE] Invalid argument: sMessageID must be a string")
	assert(istable(tData),			"[CORE] Invalid argument: tData must be a table")

	local tPeer	= self:IsValidClient(sID)
	if not tPeer then
		return MsgC(Color(231,76,60), "[CORE] Attempted to send message to unregistered Client [ID : "..sID.."]  : "..tostring(tPeer).."\n")
	end

	self.EVENTS:Call(self, self.EVENTS:BuildEvent("send", tPeer, {
		id		=	sMessageID,
		packet	=	tData,
		flag	=	isstring(sFlag) and sFlag or "reliable"
	}, isnumber(iChannel) and iChannel or 0))

end

return Class{
	
	--- BASE METHODS ---
	init			=	function(self)
		
	end,
	--------------------
	
	--- CUSTOM METHODS ---
	Update			=	function(self, iDt)
		
	end,

	Close			=	function(self)
		if not self._HOST then return end
		self._HOST:flush()
		self._HOST	=	nil
		
		self.Logger:Log(2, "Server stopped at : " ..os.date("%Y-%m-%d %H:%M:%S"))
		self.Logger:Close()
	end,
	
	SendToClient	=	function(self, sID, sMessageID, tData, iChannel, sFlag)
		assert(type(sID) == "number",			"ERROR ...")
		assert(type(sMessageID) == "string",	"ERROR ...")
		assert(type(tData) == "table",			"ERROR ...")
		
		local tPeer	=	self:IsValidClient(sID)
		if not tPeer then return self.Logger:Log(2, "Attempted to send message to unregister Client [ID : "..sID.."]  : "..tostring(tPeer)) end
		
		self._EVENTS:Call(self, self._EVENTS:BuildEvent("send", tPeer, {
			id		=	sMessageID,
			packet	=	tData,
			flag	=	(type(sFlag) == "string") and sFlag or "reliable"
		}, (type(iChannel) == "number") and iChannel or 0))
	end,
	
	SendToClients	=	function(self, tData, iChannel, sFlag)
		for sID, tClient in pairs(self._CLIENTS) do
			if not (type(tClient) == "table" and next(tClient)) then goto continue end; self:SendToClient(sID, tData, iChannel, sFlag); ::continue::
		end
	end,
	--------------------
	
	AddNetworkID	=	function(self, sID)
		assert((type(sID) == "string"), "ERROR ...")
		self._NETWORK_ID[sID]	=	true
	end,
	
	SubNetworkID	=	function(self, sID)
		assert((type(sID) == "string"), "ERROR ...")
		self._NETWORK_ID[sID]	=	nil
	end,
	
	IsValidClient	=	function(self, sID)
		return ((type(sID) == "string") and (type(self._CLIENTS[sID]) == "table") and next(self._CLIENTS[sID])) and self._CLIENTS[sID] or false
	end,
	
	IsValidMessage	=	function(self, sID)
		return (type(sID) == "string") and self._NETWORK_ID[sID]
	end,
	
	AddHook 		=	function(self, sID, fCallBack) self._HOOKS:AddHook(sID, fCallBack); end,
}
